//
//  ZTextEditor.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 2/19/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//

import Foundation

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

let gTextEditor = ZTextEditor()
var gCurrentlyEditingWidget: ZoneTextWidget? { return gTextEditor.currentTextWidget }

class ZTextPack: NSObject {

	let          createdAt =           Date()
    var         packedZone :           Zone?
    var        packedTrait :         ZTrait?
    var       originalText :         String?
    var         textWidget : ZoneTextWidget? { return widget?.textWidget }
    var             widget :     ZoneWidget? { return packedZone?.widget }
    var     isEditingEmail :           Bool  { return packedTrait?.traitType == .tEmail }
    var isEditingHyperlink :           Bool  { return packedTrait?.traitType == .tHyperlink }
    var   adequatelyPaused :           Bool  { return Date().timeIntervalSince(createdAt) > 0.1 }


    var displayType: String {
        if  let        trait = packedTrait {
            return     trait.emptyName
        } else if let  zone = packedZone {
            return     zone.emptyName
        }

        return kNoValue
    }


    var unwrappedName: String {
        if  let        trait = packedTrait {
            return     trait.unwrappedName
        } else if let  zone = packedZone {
            return     zone.unwrappedName
        }

        return kNoValue
    }


    var textWithSuffix: String {
        var   result = displayType

        if  let zone = packedZone {
            result   = zone.unwrappedName
            var need = 0

            switch gCountsMode {
            case .fetchable: need = zone.indirectCount
            case .progeny:   need = zone.progenyCount + 1
            default:         return result
            }

            var suffix: String?

            // //////////////////////////////////
            // add suffix for "show counts as" //
            // //////////////////////////////////

			if  gDebugMode.contains(.names) && zone.record != nil {
                suffix = zone.recordName
            } else if (need > 1) && (!zone.showingChildren || (gCountsMode == .progeny)) {
                suffix = String(describing: need)
            }

            if  let s = suffix {
                result.append("  ( \(s) )")
            }
        }

        return result
    }

    
    // MARK:- internals: editing zones and traits
    // MARK:-

	convenience init(_ iZRecord: ZRecord) {
        self.init()
        self.edit(iZRecord)
    }


    func updateText(isEditing: Bool = false) {
        textWidget?.text = isEditing ? unwrappedName : textWithSuffix
    }


    func edit(_ iZRecord: ZRecord) {
        packedTrait      = iZRecord as? ZTrait
        packedZone       = iZRecord as? Zone ?? packedTrait?.ownerZone
        originalText     = unwrappedName
        textWidget?.text = originalText
    }


    func isEditing(_ iZRecord: ZRecord) -> Bool {
        return packedZone == iZRecord || packedTrait == iZRecord
    }


    func updateWidgetsForEndEdit() {
        if  let t = textWidget {
            t.abortEditing()     // this does NOT remove selection highlight !!!!!!!
            t.deselectAllText()  // this does
            t.updateTextColor()
            t.layoutText()
        }

		if  let w = widget {
            w.layoutDots()
            w.revealDot.setNeedsDisplay()
            w.setNeedsDisplay()
        }
    }


    func capture(_ iText: String?) {
        let text           = iText == displayType ? nil : iText

        if  let     trait  = packedTrait {      // traits take logical priority
            trait.ownerZone?.setTextTrait(text, for: trait.traitType)
        } else if let zone = packedZone {       // ignore zone if editing a trait, above
            zone.records?.unregisterName(of: zone)

            zone.zoneName  = text

            zone.records?.registerName(of: zone)
            zone.maybeNeedSave()
        }
    }


    func removeSuffix(from iText: String?) -> String? {
        var newText: String?

        if  let components = iText?.components(separatedBy: "  (") {
            newText        = components[0]

            if  newText == displayType || newText == "" {
                newText  = nil
            }
        }

        return newText
    }


    func captureTextAndUpdateWidgets(_ iText: String?) {
        capture(iText)
        updateWidgetsForEndEdit()
    }


    func captureTextAndSync(_ iText: String?) {
        if  originalText             != iText {
            let               newText = removeSuffix(from: iText)
            gTextCapturing            = true

			printDebug(.edit, "[stop]    \(iText ?? "")")

            if  let                 w = textWidget {
                let          original = originalText
                prepareUndoForTextChange(kUndoManager) {
                    self.originalText = w.text

                    self.captureTextAndSync(original)
                    w.updateGUI()
                }
            }

            captureTextAndUpdateWidgets(newText)

            if  packedTrait == nil { // only if zone name is being edited
                updateBookmarkAssociates()
            }

            gTextCapturing = false

//            redrawAndSync()
        }
    }

    
    func updateBookmarkAssociates() {
        if  var       zone = packedZone,
            let    newText = zone.zoneName {

            if  let target = zone.bookmarkTarget {
                zone       = target
                
                ZTextPack(target).captureTextAndUpdateWidgets(newText)
            }
            
            for bookmark in zone.fetchedBookmarks {
                ZTextPack(bookmark).captureTextAndUpdateWidgets(newText)
            }
        }
    }

	func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        if  let text = textWidget?.text,
            text    != originalText {
            manager?.registerUndo(withTarget:self) { iUndoSelf in
                let                newText = iUndoSelf.textWidget?.text ?? ""
                iUndoSelf.textWidget?.text = iUndoSelf.originalText
                iUndoSelf.originalText     = newText

                onUndo()
            }
        }
    }

}

class ZTextEditor: ZTextView {

    var  cursorOffset: CGFloat?
    var currentOffset: CGFloat?
	var currentEdit: ZTextPack?
	var currentTextWidget: ZoneTextWidget?
    var currentlyEditingZone: Zone? { return currentEdit?.packedZone }
    var currentZoneName: String { return currentlyEditingZone?.zoneName ?? "" }
    var currentFont: ZFont { return currentTextWidget?.font ?? gWidgetFont }
    var atEnd:   Bool { return selectedRange.lowerBound == currentTextWidget?.text?.length ?? -1 }
    var atStart: Bool { return selectedRange.upperBound == 0 }

    // MARK:- editing
    // MARK:-

    func clearOffset() { currentOffset = nil }

	func  clearEdit() {
		currentEdit       = nil
		currentTextWidget = nil

		clearOffset()
		fullResign()
		gSetGraphMode()
	}

    func cancel() {
        if  let    e = currentEdit,
            let zone = currentlyEditingZone {
            clearEdit()
            zone.grab()
            e.updateWidgetsForEndEdit()
        }
    }

    @discardableResult func updateText(inZone: Zone?, isEditing: Bool = false) -> ZTextPack? {
        var pack: ZTextPack?
        
        if  let zone = inZone {
            pack = ZTextPack(zone)
            pack?.updateText(isEditing: isEditing)
        }
        
        return pack
    }

	func edit(_ zRecord: ZRecord, andSelect text: String?) {
		edit(zRecord)
		self.selectText(text) // TODO: this fails during search resolve
    }

    func edit(_ zRecord: ZRecord) {
		guard let zone = gRemoteStorage.maybeZoneForRecordName(zRecord.recordName) else { return }

		gSetEditIdeaMode()

		let widget = zone.widget?.textWidget

		if  currentTextWidget == nil { 			// prevent infinite recursion inside makeFirstResponder, called below
			printDebug(.edit, "[make]    \(zone)")
			gWindow?.makeFirstResponder(widget)
			widget?.enableUndo()
		} else {
            let        pack = ZTextPack(zRecord)
			if  zone.userCanWrite {
				currentEdit = pack

				pack.updateText(isEditing: true)

				deferEditingStateChange()
				gSelecting.ungrabAll(retaining: [zone])		// so crumbs will appear correctly
				signalMultiple([.eRelayout]) {
					printDebug(.edit, "[edit]    \(zone)")

					if  let at = gCurrentMouseDownLocation {
						self.setCursor(at: at)
					} else {
						widget?.selectAllText()
					}
				}
			}
        }
    }

	func placeCursorAtEnd() {
        selectedRange = NSMakeRange(-1, 0)
    }

	func applyPreservingOffset(_ closure: Closure) {
        let o = currentOffset
        
        closure()
        
        currentOffset = o
    }

	func applyPreservingEdit(_ closure: Closure) {
        let e = currentEdit

        applyPreservingOffset {
            closure()
        }
        
        currentEdit = e
    }

    
    func quickStopCurrentEdit() {
        if  let e = currentEdit {
            applyPreservingEdit {
                capture()
                e.packedZone?.grab()
            }
        }
    }

	func stopCurrentEdit(forceCapture: Bool = false) {
        if  let e = currentEdit, !gIsEditingStateChanging {
			capture(force: forceCapture)
            clearEdit()
            fullResign()
            e.updateWidgetsForEndEdit()
            e.packedZone?.grab()
			signalMultiple([.eCrumbs])
        }
    }


    func deferEditingStateChange() {
        gIsEditingStateChanging     = true

        FOREGROUND(after: 0.1) {
            gIsEditingStateChanging = false
        }
    }

	func capture(force: Bool = false) {
        if  let current = currentEdit, let text = current.textWidget?.text, (!gTextCapturing || force) {
            current.captureTextAndSync(text)
        }
    }

    func assign(_ iText: String?, to iZone: Zone?) {
        if  let zone = iZone {
            ZTextPack(zone).captureTextAndSync(iText)
        }
    }

    func prepareUndoForTextChange(_ manager: UndoManager?,_ onUndo: @escaping Closure) {
        currentEdit?.prepareUndoForTextChange(manager, onUndo)
    }

	// MARK:- events
	// MARK:-

	@IBAction func genericMenuHandler(_ iItem: ZMenuItem?) { gDesktopAppDelegate?.genericMenuHandler(iItem) }

    func moveOut(_ iMoveOut: Bool) {
        gArrowsDoNotBrowse = true

        let editAtOffset: FloatClosure = { iOffset in
            if  let  grabbed = gSelecting.firstSortedGrab {
				let location = iOffset.convertLocation(from: self)
				printDebug(.edit, "[move]    \(location)")
				gTemporarilySetMouseDownLocation(location)
                self.edit(grabbed)
            }

			gArrowsDoNotBrowse = false
        }
        
        if  iMoveOut {
            quickStopCurrentEdit()
            gGraphEditor.moveOut {
                editAtOffset(100000000.0)
            }
        } else if currentlyEditingZone?.children.count ?? 0 > 0 {
            quickStopCurrentEdit()
            gGraphEditor.moveInto {
                editAtOffset(0.0)
            }
        }
    }

	func editingOffset(_ atStart: Bool) -> CGFloat {
        return currentTextWidget?.offset(for: selectedRange, atStart) ?? 0.0
    }

	func moveUp(_ iMoveUp: Bool, stopEdit: Bool) {
        currentOffset   = currentOffset ?? editingOffset(iMoveUp)
        let currentZone = currentlyEditingZone
        let      isHere = currentZone == gHere
        let           e = currentEdit // for the case where stopEdit is true

        if  stopEdit {
            applyPreservingOffset {
                capture()
                currentZone?.grab()
            }
        }
        
        if  var original = currentZone {
			gGraphEditor.moveUp(iMoveUp, [original], targeting: currentOffset) { iKind in
                gControllers.signalFor(nil, regarding: iKind) {
                    if  isHere {
                        self.currentOffset = currentZone?.widget?.textWidget.offset(for: self.selectedRange, iMoveUp)  // offset will have changed when current == here
                    }
                    
                    if  stopEdit,
                        let first = gSelecting.firstSortedGrab {
                        original  = first
                        
                        if  original != currentZone { // if move up (above) does nothing, ignore
							gTemporarilySetMouseDownLocation(self.currentOffset)
                            self.edit(original)
                        } else {
                            self.currentEdit = e // restore after capture sets it to nil

                            gSelecting.ungrabAll()
                            e?.textWidget?.becomeFirstResponder()
                        }
                    } // else widgets are wrong
                    
                    FOREGROUND(after: 0.01) {
                        self.setCursor(at: self.currentOffset)
                    }
                }
            }
        }
    }

	// MARK:- selecting
	// MARK:-

	func selectText(_ iText: String?) {
		if	let widget = currentTextWidget,
			let   text =  widget.text?.searchable,
			let ranges = text.rangesMatching(iText),
			ranges.count > 0 {
			let range  = ranges[0]

			widget.select(range: range)
		}
	}

	func setCursor(at iOffset: CGFloat?) {
        gArrowsDoNotBrowse = false

        if  var   offset = iOffset,
            let     zone = currentlyEditingZone,
            let       to = currentTextWidget {
			var    point = CGPoint.zero
            point        = to.convert(point, from: nil)
			offset      += point.x - 3.0   // subtract half the average character width -> closer to user expectation
            let     name = zone.unwrappedName
            let location = name.location(of: offset, using: currentFont)

			to.select(from: location, to: location)
        }
    }
    
}
