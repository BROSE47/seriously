//
//  ZRingView.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 2/16/19.
//  Copyright © 2019 Jonathan Sand. All rights reserved.
//

#if os(OSX)
import Cocoa
#elseif os(iOS)
import UIKit
#endif

class ZRingView: ZView {

	struct ZGeometry {
		var one   = CGRect()
		var thick = CGFloat()
	}

	var geometry         = ZGeometry()
	var necklaceObjects  = ZObjectsArray()
	var necklaceDotRects = [Int : CGRect]()
	let necklaceMax 	 = 16

	func itemInRect(_ rect: CGRect?) -> Bool { return item(containedIn: rect) != nil }

	override func awakeFromNib() {
		super.awakeFromNib()

		zlayer.backgroundColor = kClearColor.cgColor
	}

	func update() {
		let     square = CGSize(width: 130.0, height: 130.0)
		let     origin = CGPoint(x: bounds.maxX - square.width - 50.0, y: bounds.maxY - square.height - 90.0)
		geometry  .one = CGRect(origin: origin, size: square)
		geometry.thick = square.height / 40.0
	}

	// MARK:- draw
	// MARK:-

	func drawControl(for index: Int) {
		ZRingControl.controls[index].draw(controlRects[index])
	}

	override func draw(_ iDirtyRect: CGRect) {
		super.draw(iDirtyRect)

		if !gHasFinishedStartup { return }

		let color = gNecklaceDotColor

		color.setStroke()
		kClearColor.setFill()
		necklaceDotRects.removeAll()

		if !gFullRingIsVisible {
			drawControl(for: 1)
		} else {
			let            g = geometry
			let         rect = g.one
			let surroundRect = rect.insetBy(dx: -6.0, dy: -6.0)
			let       radius = Double(surroundRect.size.width) / 27.0

			ZBezierPath.drawCircle (in: rect, thickness: g.thick)

			drawNecklaceDots(surrounding: surroundRect, objects: necklaceObjects, radius: radius, color: color, countMax: necklaceMax + 1) { (index, rect) in
				self.necklaceDotRects[index] = rect
			}

			for index in 0 ... (controlRects.count - 1) {
				drawControl(for: index)
			}

			addToolTips()
		}
	}

	// MARK:- respond
	// MARK:-

	func respondToRingControl(_ item: NSObject) -> Bool {
		if  let    control = item as? ZRingControl {
			return control.respond()
		}

		return false
	}

	func focusOnIdea(_ idea: Zone) {
		gControllers.swapGraphAndEssay(force: .graphMode)
		gFocusRing.focusOn(idea) {
			gControllers.signalFor(idea, regarding: .eRelayout)
		}
	}

	func focusOnEssay(_ note: ZNote) {
		gEssayView?.resetCurrentEssay(note)
		gControllers.swapGraphAndEssay(force: .noteMode)
		signalMultiple([.eCrumbs, .eRing])
	}

	func respond(to item: NSObject, CONTROL: Bool = false, COMMAND: Bool = false) -> Bool {
		if  CONTROL {
			var removeMe = item

			if  let dual = item as? ZObjectsArray {
				removeMe = gIsNoteMode ? dual[1] : dual[0]
			}

			if  removeFromRings(removeMe) {
				return true
			}
		} else if let idea = item as? Zone {
			if !COMMAND, ((idea != gHere) || gIsNoteMode) {
				focusOnIdea(idea)
			} else if COMMAND, idea.countOfNotes > 0 {
				focusOnEssay(idea.note)
			} else {
				return false
			}

			return true
		} else if let note = item as? ZNote,
			let idea = note.zone {
			if !COMMAND, ((idea != gCurrentEssay?.zone) || !gIsNoteMode) {
				focusOnEssay(note)
			} else if COMMAND {
				focusOnIdea(idea)
			} else {
				return false
			}

			return true
		}

		return false
	}

	@discardableResult func handleClick(in rect: CGRect?, flags: ZEventFlags = ZEventFlags()) -> Bool {   // false means click was ignored
		if  let item = self.item(containedIn: rect) {
			let CONTROL = flags.isControl
			let COMMAND = flags.isCommand

			if (gFullRingIsVisible && respond(to: item, CONTROL: CONTROL, COMMAND: COMMAND)) || respondToRingControl(item) { // single item
				signalMultiple([.eRelayout])

				return true
			} else if var subitems = item as? ZObjectsArray {	  // array of items
				if  gIsNoteMode ^^ COMMAND {
					subitems = subitems.reversed()
				}

				for subitem in subitems {
					if  respond(to: subitem, CONTROL: CONTROL) {
						signalMultiple([.eRelayout])

						return true
					}
				}
			}
		} else if gIsNoteMode, let v = gEssayView, rect != nil, !v.frame.contains(rect!) {
			v.save()
			gControllers.swapGraphAndEssay(force: .graphMode)

			return true
		}

		return false
	}

	override func mouseDown(with event: ZEvent) {
		let   rect = CGRect(origin: event.locationInWindow, size: CGSize())
		let inRing = handleClick(in: rect, flags: event.modifierFlags)

		if !inRing {
			super.mouseDown(with: event)
		}
	}

	// MARK:- necklace
	// MARK:-

	func addUnique(from ring: ZObjectsArray) {
		for object in ring.reversed() {
			guard let (index, same, dual) = necklaceIndexOf(object) else {
				addToNecklace(object, at: nil)

				continue
			}

			if !dual, !same {
				let           original = necklaceObjects[index]
				let             isZone = original.isKind(of: Zone.self)
				let              array = isZone ? [original, object] : [object, original]

				addToNecklace(array as NSObject, at: index)
			}
		}
	}

	func addToNecklace(_ object: NSObject, at iIndex: Int?) {
		var index: Int? = iIndex

		if  index != nil {
			necklaceObjects[index!] = object
		} else {
			necklaceObjects.append(object)
			index = necklaceObjects.count - 1
		}

		printDebug(.ring, "v     add: \(necklaceObjects[index!])")
	}

	func removeFromNecklace(_ index: Int) {
		printDebug(.ring, "v  remove: \(necklaceObjects[index])")
		necklaceObjects.remove(at: index)
	}

	@discardableResult func removeFromRings(_ item: NSObject, okayToRecurse: Bool = true) -> Bool {
		guard let array = item as? ZObjectsArray else {
			return gFocusRing.removeFromStack(item, okayToRecurse: okayToRecurse) || gEssayRing.removeFromStack(item, okayToRecurse: okayToRecurse) // recursion is okay: can call update necklace within
		}

		var result =           gFocusRing.removeFromStack(array[0], okayToRecurse: okayToRecurse)   // MUST invoke on both rings
		result     = result || gEssayRing.removeFromStack(array[1], okayToRecurse: okayToRecurse)

		return result
	}

	func removeStale() {
		let array = Array(necklaceObjects.reversed())

		for (reverseIndex, object) in array.enumerated() {
			let index = array.count - reverseIndex - 1

			if  necklaceObjects.count <= index {
				continue
			} else if object.isKind(of:  Zone.self), !gFocusRing.ring.contains(object) {
				removeFromNecklace(index)
			} else if object.isKind(of: ZNote.self), !gEssayRing.ring.contains(object) {
				removeFromNecklace(index)
			} else if let dual = object as? ZObjectsArray {
				let     zone = dual[0]
				let     note = dual[1]
				var keepZone = false
				var keepNote = false

				if  gFocusRing.ring.contains(zone) {
					keepZone = true
				}

				if  gEssayRing.ring.contains(note) {
					keepNote = true
				}

				if !keepZone && !keepNote {
					removeFromNecklace(index)
				} else if keepZone && !keepNote {
					addToNecklace(zone, at: index)
				} else if keepNote && !keepZone {
					addToNecklace(note, at: index)
				}
			}
		}
	}

	func removeExtras() {
		while necklaceObjects.count > necklaceMax {
			removeFromRings(necklaceObjects[0], okayToRecurse: false)
			removeFromNecklace(0)
		}
	}

	func updateNecklace(okayToSignal: Bool = true) {
		addUnique(from: gFocusRing.ring)
		addUnique(from: gEssayRing.ring)
		removeStale()
		removeExtras()

		if  okayToSignal {
			signalMultiple([.eRing])
		} else {
			setNeedsDisplay()
		}
	}

	func necklaceIndexOf(_ item: NSObject) -> (Int, Bool, Bool)? {
		if  let index = necklaceObjects.firstIndex(of: item) {
			return (index, true, false)
		}

		let recordName = (item as? ZIdentifiable)?.recordName()

		for (index, object) in necklaceObjects.enumerated() {
			if  let subObjects = object as? ZObjectsArray {
				for subObject in subObjects {
					if  let subName = (subObject as? ZIdentifiable)?.recordName(),
						subName == recordName {
						return (index, true, true)
					}
				}
			} else if let identifiable = object as? ZIdentifiable,
				identifiable.recordName() == recordName {
				return (index, false, false)
			}
		}

		return nil
	}

	func copyObjects(from ring: ZObjectsArray) {
		for object in ring {
			if object.isKind(of: Zone.self) {
				addToNecklace(object, at: nil)
			} else if let  essay = object as? ZNote,
				let idea = essay.zone {

				if  let index = necklaceObjects.firstIndex(of: idea) {
					addToNecklace([idea, essay] as NSObject, at: index)
				} else {
					addToNecklace(object, at: nil)
				}
			}
		}
	}

	// MARK:- controls
	// MARK:-

	var controlRects : [CGRect] {
		let   rect = geometry.one
		let radius = rect.width / 4.5
		let offset = rect.width / 3.7
		let center = rect.center
		var result = [CGRect]()

		for index in 0 ... 2 {
			let increment = 2.0 * .pi / 3.2 	// 1/3.2 of circle (2 pi)
			let     angle = (1.8 - Double(index)) * increment
			let         x = center.x + (offset * CGFloat(cos(angle)))
			let         y = center.y + (offset * CGFloat(sin(angle)))
			let   control = NSRect(origin: CGPoint(x: x, y: y), size: CGSize()).insetBy(dx: -radius, dy: -radius)

			result.append(control)
		}

		return result
	}

	private func item(containedIn iRect: CGRect?) -> NSObject? {
		if  let     rect = iRect {
			let  objects = necklaceObjects 				// expensive computation: do once
			let    count = objects.count
			let controls = ZRingControl.controls

			for (index, controlRect) in controlRects.enumerated() {
				if  rect.intersectsOval(within: controlRect) {
					let control = controls[index]

					if  control.shape(in: controlRect, contains: rect.origin) {
						return control
					}
				}
			}

			for (index, dotRect) in necklaceDotRects {
				if  index < count, 						// avoid crash
					rect.intersects(dotRect) {
					return objects[index]
				}
			}

			if  rect.intersectsOval(within: geometry.one) {
				return ZRingControl.tooltips
			}
		}

		return nil
	}

	@discardableResult override func addToolTip(_ rect: NSRect, owner: Any, userData data: UnsafeMutableRawPointer?) -> NSView.ToolTipTag {
		if !gToolTipsAlwaysVisible {
			return super.addToolTip(rect, owner: owner, userData: data)
		} else if  let tool = owner as? ZToolable,
			let        name = tool.toolName() {
			let        font = gFavoritesFont
			var    nameRect = name.rectWithFont(font, options: .usesFontLeading).insetBy(dx: -10.0, dy: 0.0)
			nameRect.center = rect.offsetBy(dx: 10.0, dy: 1.0).center
			var  attributes : [NSAttributedString.Key : Any] = [.font : font]

			if  let   color = tool.toolColor() {
				attributes[.foregroundColor] = color
			}

			name.draw(in: nameRect, withAttributes: attributes)
		}

		return 0
	}

	func addToolTips() {
		let       controls = ZRingControl.controls
		let        objects = necklaceObjects 				// expensive computation: do once
		let          count = objects.count

		removeAllToolTips()

		for (index, tinyRect) in necklaceDotRects {
			if  index < count { 							// avoid crash
				var      owner = objects[index]
				let       rect = self.convert(tinyRect, to: self)

				if  let owners = owner as? [NSObject] {
					owner      = owners[0]
				}

				addToolTip(rect, owner: owner, userData: nil)
			}
		}

		for (index, controlRect) in controlRects.enumerated() {
			let  rect = self.convert(controlRect, to: self).offsetBy(dx: 0.0, dy: -5.0)
			let owner = controls[index]

			addToolTip(rect, owner: owner, userData: nil)
		}
	}
}
