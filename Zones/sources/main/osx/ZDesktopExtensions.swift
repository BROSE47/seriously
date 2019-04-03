//
//  ZDesktopExtensions.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/31/17.
//  Copyright © 2017 Jonathan Sand. All rights reserved.
//


import Foundation
import AppKit
import Cocoa


enum ZArrowKey: CChar {
    case up    = -128
    case down
    case left
    case right
}


public typealias ZFont                      = NSFont
public typealias ZView                      = NSView
public typealias ZAlert                     = NSAlert
public typealias ZEvent                     = NSEvent
public typealias ZImage                     = NSImage
public typealias ZColor                     = NSColor
public typealias ZButton                    = NSButton
public typealias ZSlider                    = NSSlider
public typealias ZWindow                    = NSWindow
public typealias ZControl                   = NSControl
public typealias ZMenuItem                  = NSMenuItem
public typealias ZClipView                  = NSClipView
public typealias ZTextView                  = NSTextView
public typealias ZTextField                 = NSTextField
public typealias ZTableView                 = NSTableView
public typealias ZStackView                 = NSStackView
public typealias ZColorWell                 = NSColorWell
public typealias ZButtonCell                = NSButtonCell
public typealias ZBezierPath                = NSBezierPath
public typealias ZScrollView                = NSScrollView
public typealias ZController                = NSViewController
public typealias ZEventFlags                = NSEvent.ModifierFlags
public typealias ZSearchField               = NSSearchField
public typealias ZApplication               = NSApplication
public typealias ZTableColumn               = NSTableColumn
public typealias ZTableRowView              = NSTableRowView
public typealias ZTableCellView             = NSTableCellView
public typealias ZWindowDelegate            = NSWindowDelegate
public typealias ZWindowController          = NSWindowController
public typealias ZSegmentedControl          = NSSegmentedControl
public typealias ZTextViewDelegate          = NSTextViewDelegate
public typealias ZTextFieldDelegate         = NSTextFieldDelegate
public typealias ZGestureRecognizer         = NSGestureRecognizer
public typealias ZProgressIndicator         = NSProgressIndicator
public typealias ZTableViewDelegate         = NSTableViewDelegate
public typealias ZTableViewDataSource       = NSTableViewDataSource
public typealias ZSearchFieldDelegate       = NSSearchFieldDelegate
public typealias ZApplicationDelegate       = NSApplicationDelegate
public typealias ZPanGestureRecognizer      = NSPanGestureRecognizer
public typealias ZClickGestureRecognizer    = NSClickGestureRecognizer
public typealias ZGestureRecognizerState    = NSGestureRecognizer.State
public typealias ZGestureRecognizerDelegate = NSGestureRecognizerDelegate


let        gVerticalWeight = 1.0
let gHighlightHeightOffset = CGFloat(-3.0)


var gIsPrinting: Bool {
    return NSPrintOperation.current != nil
}


protocol ZScrollDelegate : NSObjectProtocol {}


func isDuplicate(event: ZEvent? = nil, item: ZMenuItem? = nil) -> Bool {
    if  let e  = event {
        if  e == gCurrentEvent {
            return true
        } else {
            gCurrentEvent = e
        }
    }
    
    if  item != nil {
        return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4)
    }
    
    return false
}


// Helper function inserted by Swift 4.2 migrator.
func convertFromOptionalUserInterfaceItemIdentifier(_ input: NSUserInterfaceItemIdentifier?) -> String? {
    guard let input = input else { return nil }
    return input.rawValue
}


extension NSObject {
    func assignAsFirstResponder(_ responder: NSResponder?) {
        if  let window = gWindow,
            ![window, responder].contains(window.firstResponder) {
            window.makeFirstResponder(responder)
        }
    }
}


extension String {


    func heightForFont(_ font: ZFont, options: NSString.DrawingOptions = []) -> CGFloat { return sizeWithFont(font, options: options).height }
    func sizeWithFont (_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGSize { return rectWithFont(font, options: options).size }
    
    
    func  rectWithFont(_ font: ZFont, options: NSString.DrawingOptions = .usesFontLeading) -> CGRect {
        let attributes = convertToOptionalNSAttributedStringKeyDictionary([kCTFontAttributeName as String : font])
        
        return self.boundingRect(with: CGSize.big, options: options, attributes: attributes, context: nil)
    }
    
    var cgPoint: CGPoint {
        let point = NSPointFromString(self)

        return CGPoint(x: point.x, y: point.y)
    }

    var cgSize: CGSize {
        let size = NSSizeFromString(self)
        
        return CGSize(width: size.width, height: size.height)
    }

    var cgRect: CGRect {
        let rect = NSRectFromString(self)
        
        return CGRect(x: rect.origin.x, y: rect.origin.y, width: rect.size.width, height: rect.size.height)
    }

    var arrow: ZArrowKey? {
        if containsNonAscii {
            let character = utf8CString[2]
            
            for arrowKey in ZArrowKey.up.rawValue...ZArrowKey.right.rawValue {
                if arrowKey == character {
                    return ZArrowKey(rawValue: character)
                }
            }
        }
        
        return nil
    }
    
    
    func openAsURL() {
        let fileScheme = "file"
        let filePrefix = fileScheme + "://"
        let  urlString = (replacingOccurrences(of: "\\", with: "").replacingOccurrences(of: " ", with: "%20") as NSString).expandingTildeInPath
        
        if  var url = NSURL(string: urlString) {
            if  urlString.character(at: 0) == "/" {
                url = NSURL(string: filePrefix + urlString)!
            }

            if  url.scheme != fileScheme {
                url.open()
            } else if let path = url.path {
                url = NSURL(fileURLWithPath: path)

                url.openAsFile()
            }
        }
    }
    
}


extension NSURL {
    
    var directoryURL: URL? {
        return nil
    }

    
    func open() {
        NSWorkspace.shared.open(self as URL)
    }

    
    func openAsFile() {
        if !self.openSecurely() {
            ZFiles.presentOpenPanel() { (iAny) in
                if  let url = iAny as? NSURL {
                    url.open()
                } else if let panel = iAny as? NSPanel {
                    if    let  name = self.lastPathComponent {
                        panel.title = "Open \(name)"
                    }
                    
                    panel.setDirectoryAndExtensionFor(self as URL)
                }
            }
        }
    }

}


extension ZApplication {

    func clearBadge() {
        dockTile.badgeLabel = ""
    }
    
    func showHideAbout() {
        for     window in windows {
            if  window.title == "",
                window.isKeyWindow {
                window.close()
                
                return
            }
        }
        
        orderFrontStandardAboutPanel(nil)
    }
    
}


extension NSEvent.ModifierFlags {
    var isNumericPad: Bool { return contains(.numericPad) }
    var isControl:    Bool { return contains(.control) }
    var isCommand:    Bool { return contains(.command) }
    var isOption:     Bool { return contains(.option) }
    var isShift:      Bool { return contains(.shift) }
}


extension NSEvent {
    var arrow: ZArrowKey? { return key?.arrow }
    var   key:    String? { return input?.character(at: 0) }
    var input:    String? { return charactersIgnoringModifiers }
}


extension ZColor {


    var string: String {
        return "red:\(redComponent),blue:\(blueComponent),green:\(greenComponent)"
    }

    func darker(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent * (by * 2.0), brightness: brightnessComponent / (by / 3.0), alpha: alphaComponent)
    }

    func darkish(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent,              brightness: brightnessComponent / by,         alpha: alphaComponent)
    }

    func lighter(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent / (by / 2.0), brightness: brightnessComponent * (by / 3.0), alpha: alphaComponent)
    }
    
    func lightish(by: CGFloat) -> NSColor {
        return NSColor(calibratedHue: hueComponent, saturation: saturationComponent,              brightness: brightnessComponent * by,         alpha: alphaComponent)
    }

    var inverted: ZColor {
        let b = max(0.0, min(1.0, 1.25 - brightnessComponent))
        let s = max(0.0, min(1.0, 1.45 - saturationComponent))
        
        return ZColor(calibratedHue: hueComponent, saturation: s, brightness: b, alpha: alphaComponent)
    }
    
}


extension NSBezierPath {
    public var cgPath: CGPath {
        let   path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)

        for i in 0 ..< self.elementCount {
            let type = self.element(at: i, associatedPoints: &points)

            switch type {
            case .closePath: path.closeSubpath()
            case .moveTo:    path.move    (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .lineTo:    path.addLine (to: CGPoint(x: points[0].x, y: points[0].y) )
            case .curveTo:   path.addCurve(to: CGPoint(x: points[2].x, y: points[2].y),
                                                      control1: CGPoint(x: points[0].x, y: points[0].y),
                                                      control2: CGPoint(x: points[1].x, y: points[1].y) )
            }
        }

        return path
    }


    public convenience init(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        self.init(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    }
}


extension NSView {
    var      zlayer:                CALayer { get { wantsLayer = true; return layer! } set { layer = newValue } }
    var recognizers: [NSGestureRecognizer]? { return gestureRecognizers }


    var gestureHandler: ZGraphController? {
        get { return nil }
        set {
            clearGestures()

            if let e = newValue {
                e.movementGesture = createDragGestureRecognizer (e, action: #selector(ZGraphController.dragGestureEvent))
                e.clickGesture    = createPointGestureRecognizer(e, action: #selector(ZGraphController.clickEvent), clicksRequired: 1)
                gDraggedZone      = nil
            }
        }
    }


    func setNeedsDisplay() { if !gDeferRedraw { needsDisplay = true } }
    func setNeedsLayout () { needsLayout  = true }
    func insertSubview(_ view: ZView, belowSubview siblingSubview: ZView) { addSubview(view, positioned: .below, relativeTo: siblingSubview) }

    
    func setShortestDimension(to: CGFloat) {
        if  frame.size.width  < frame.size.height {
            frame.size.width  = to
        } else {
            frame.size.height = to
        }
    }
    

    @discardableResult func createDragGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?) -> ZKeyPanGestureRecognizer {
        let                            gesture = ZKeyPanGestureRecognizer(target: target, action: action)
        gesture                      .delegate = target
        gesture               .delaysKeyEvents = false
        gesture.delaysPrimaryMouseButtonEvents = false

        addGestureRecognizer(gesture)

        return gesture
    }


    @discardableResult func createPointGestureRecognizer(_ target: ZGestureRecognizerDelegate, action: Selector?, clicksRequired: Int) -> ZKeyClickGestureRecognizer {
        let                            gesture = ZKeyClickGestureRecognizer(target: target, action: action)
        gesture.numberOfClicksRequired         = clicksRequired
        gesture.delaysPrimaryMouseButtonEvents = false
        gesture.delegate                       = target

        addGestureRecognizer(gesture)

        return gesture
    }
    
    
    func scale(for isHorizontal: Bool) -> Double {
        let       length = Double(isHorizontal ? bounds.size.width : bounds.size.height)
        let     dividend = 7200.0 * (isHorizontal ? 8.5 : 6.0) // (inches) * 72 (dpi) * 100 (percent)
        let        scale = dividend / length

        return scale
    }

    
    var scale: Double {
        let wScale = scale(for: true)
        let hScale = scale(for: false)

        return min(wScale, hScale)
    }
    

    func printView() {
        let    printInfo = NSPrintInfo.shared
        let pmPageFormat = PMPageFormat(printInfo.pmPageFormat())
        let      isWider = bounds.size.width > bounds.size.height
        let  orientation = PMOrientation(isWider ? kPMLandscape : kPMPortrait)
        
        PMSetScale(pmPageFormat, scale)
        PMSetOrientation(pmPageFormat, orientation, false)
        printInfo.updateFromPMPrintSettings()
        printInfo.updateFromPMPageFormat()
        NSPrintOperation(view: self, printInfo: printInfo).run()
    }
    
}


extension ZStackableView {
    
    var identity: ZDetailsViewID {
        if  let kind = convertFromOptionalUserInterfaceItemIdentifier(identifier) {
            switch kind {
            case "preferences": return .Preferences
            case "information": return .Information
            case       "debug": return .Debug
            case       "tools": return .Tools
            default:            return .All
            }
        }
        
        return .All
    }
    
    func turnOnTitleButton() {
        titleButton?.state = ZControl.StateValue.on
    }

}


extension NSWindow {

    @IBAction func displayPreferences(_ sender:      Any?) { gDetailsController?.view(for: .Preferences)?.toggleAction(self) }
    @IBAction func displayHelp       (_ sender:      Any?) { openBrowserForFocusWebsite() }
    @IBAction func printHere         (_ sender:      Any?) { gHere.widget?.printView() }
    @IBAction func copy              (_ iItem: ZMenuItem?) { gGraphEditor.copyToPaste() }
    @IBAction func cut               (_ iItem: ZMenuItem?) { gGraphEditor.delete() }
    @IBAction func delete            (_ iItem: ZMenuItem?) { gGraphEditor.delete() }
    @IBAction func paste             (_ iItem: ZMenuItem?) { gGraphEditor.paste() }
    @IBAction func toggleSearch      (_ iItem: ZMenuItem?) { gGraphEditor.search() }
    @IBAction func undo              (_ iItem: ZMenuItem?) { gGraphEditor.undoManager.undo() }
    @IBAction func redo              (_ iItem: ZMenuItem?) { gGraphEditor.undoManager.redo() }
}


extension ZoneWindow {
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        let        button = standardWindowButton(ZWindow.ButtonType.closeButton) // hide close button ... zoomButton miniaturizeButton
        button!.isHidden  = true
        delegate          = self
        ZoneWindow.window = self
        contentMinSize    = kDefaultWindowRect.size // smallest size user to which can shrink window
        let          rect = gWindowRect
        
        setFrame(rect, display: true)
        
        observer = observe(\.effectiveAppearance) { _, _  in
            gControllers.signalFor(nil, regarding: .eAppearance)
        }
    }
    
}


extension NSButtonCell {
    override open var objectValue: Any? {
        get { return title }
        set { title = newValue as? String ?? "" }
    }
}


extension NSButton {
    var isCircular: Bool {
        get { return true }
        set { bezelStyle = newValue ? .circular : .rounded }
    }

    var onHit: Selector? {
        get { return action }
        set { action = newValue; target = self } }
}


extension ZAlert {

    func showAlert(closure: AlertStatusClosure? = nil) {
        let             response = runModal()
        let              success = response == NSApplication.ModalResponse.alertFirstButtonReturn
        let status: ZAlertStatus = success ? .eStatusYes : .eStatusNo

        closure?(status)
    }

}


extension ZAlerts {
    
    
    func openSystemPreferences() {
        if  let url = NSURL(string: "x-apple.systempreferences:com.apple.ids.service.com.apple.private.alloy.icloudpairing") {
            url.open()
        }
    }
    
    
    func showAlert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOkayTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ closure: AlertStatusClosure? = nil) {
        alert(iMessage, iExplain, iOkayTitle, iCancelTitle, iImage) { iAlert, iState in
            switch iState {
            case .eStatusShow:
                iAlert?.showAlert { iResponse in
                    let window = iAlert?.window
                    
                    gApplication.abortModal()
                    window?.orderOut(iAlert)
                    closure?(iResponse)
                }
            default:
                closure?(iState)
            }
        }
    }
    
    
    func alert(_ iMessage: String = "Warning", _ iExplain: String? = nil, _ iOKTitle: String = "OK", _ iCancelTitle: String? = nil, _ iImage: ZImage? = nil, _ closure: AlertClosure? = nil) {
        FOREGROUND(canBeDirect: true) {
            let             a = ZAlert()
            a    .messageText = iMessage
            a.informativeText = iExplain ?? ""
            
            a.addButton(withTitle: iOKTitle)
            
            if  let cancel = iCancelTitle {
                a.addButton(withTitle: cancel)
            }
            
            if  let image = iImage {
                let size = image.size
                let frame = NSMakeRect(50, 50, size.width, size.height)
                a.accessoryView = NSImageView(image: image)
                a.accessoryView?.frame = frame
                a.layout()
            }
            
            closure?(a, .eStatusShow)
        }
    }
    
}


extension NSTextField {
    var          text:         String? { get { return stringValue } set { stringValue = newValue ?? "" } }
    var textAlignment: NSTextAlignment { get { return alignment }   set { alignment = newValue } }


    func enableUndo() {
        cell?.allowsUndo = true
    }
    
    
    func select(range: NSRange) {
        select(from: range.lowerBound, to: range.upperBound)
    }


    func select(from: Int, to: Int) {
        if  let editor = currentEditor() {
            select(withFrame: bounds, editor: editor, delegate: self, start: from, length: to)
        }
    }
    
    
    func selectFromStart(toEnd: Bool = false) {
        if  let t = text {
            select(from: 0, to: toEnd ? t.length : 0)
            gTextEditor.clearOffset()
        }
    }
    

    func deselectAllText() {
        selectFromStart()
    }
    
    
    func selectAllText() {
        gTextEditor.deferEditingStateChange()
        selectFromStart(toEnd: true)
    }
    
}


extension ZoneTextWidget {
    // override open var acceptsFirstResponder: Bool { return gBatch.isReady }    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder : Bool  { return widgetZone?.userCanWrite ?? false }


    var isFirstResponder : Bool {
        if  let    first = window?.firstResponder {
            return first == currentEditor()
        }

        return false
    }


    override func textDidChange(_ iNote: Notification) {
        gTextEditor.prepareUndoForTextChange(undoManager) {
            self.textDidChange(iNote)
        }

        if  text?.contains(kHalfLineOfDashes + " - ") ?? false {
            widgetZone?.zoneName = kLineOfDashes

            gTextEditor.updateText(inZone: widgetZone)
            gTextEditor.stopCurrentEdit()
        } else {
            updateGUI()
        }
    }


    override func textDidEndEditing(_ notification: Notification) {
        if  let       number = notification.userInfo?["NSTextMovement"] as? NSNumber, !gTextEditor.isEditingStateChanging {
            let        value = number.intValue
            let      isShift = NSEvent.modifierFlags.isShift
            var key: String?

            gTextEditor.stopCurrentEdit(forceCapture: isShift)

            switch value {
            case NSBacktabTextMovement: key = kSpace
            case NSTabTextMovement:     key = kTab
            case NSReturnTextMovement:  return
            default:                    break
            }

            FOREGROUND { // execute on next cycle of runloop
                gGraphEditor.handleKey(key, flags: ZEventFlags(), isWindow: true)
            }
        }
    }

}


extension ZTextEditor {
    
    
    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline):       stopCurrentEdit()
        case #selector(insertTab):           if currentEdit?.adequatelyPaused ?? false { gGraphEditor.addNext() { iChild in iChild.edit() } } // stupid OSX issues tab twice (to create the new idea, then AFTERWARDS
        case #selector(cancelOperation(_:)): if gSearching.state.isOneOf([.list, .entry]) { gSearching.exitSearchMode() }
        default:                             super.doCommand(by: selector)
        }
    }
    
    
    func handleArrow(_ arrow: ZArrowKey, flags: ZEventFlags) {
        if gIsShortcutsFrontmost { return }
        
        let COMMAND = flags.isCommand
        let  OPTION = flags.isOption
        let   SHIFT = flags.isShift
        
        switch arrow {
        case .up,
             .down: moveUp(arrow == .up, stopEdit: !OPTION)
        case .left:
            if  atStart {
                moveOut(true)
            } else {
                clearOffset()
                
                if         COMMAND && !SHIFT {
                    moveToBeginningOfLine(self)
                } else if  COMMAND &&  SHIFT {
                    moveToBeginningOfLineAndModifySelection(self)
                } else if  OPTION  &&  SHIFT {
                    moveWordLeftAndModifySelection(self)
                } else if !OPTION  &&  SHIFT {
                    moveLeftAndModifySelection(self)
                } else if  OPTION  && !SHIFT {
                    moveWordLeft(self)
                } else {
                    moveLeft(self)
                }
            }
        case .right:
            if atEnd {
                moveOut(false)
            } else {
                clearOffset()
                
                if         COMMAND && !SHIFT {
                    moveToEndOfLine(self)
                } else if  COMMAND &&  SHIFT {
                    moveToEndOfLineAndModifySelection(self)
                } else if  OPTION  &&  SHIFT {
                    moveWordRightAndModifySelection(self)
                } else if !OPTION  &&  SHIFT {
                    moveRightAndModifySelection(self)
                } else if  OPTION  && !SHIFT {
                    moveWordRight(self)
                } else {
                    moveRight(self)
                }
            }
        }
    }

}


extension NSSegmentedControl {


    var selectedSegmentIndex: Int {
        get { return selectedSegment }
        set { selectedSegment = newValue }
    }

}


extension NSProgressIndicator {


    func startAnimating() { startAnimation(self) }
    func  stopAnimating() {  stopAnimation(self) }

}


public extension ZImage {


    public func imageRotatedByDegrees(_ degrees: CGFloat) -> ZImage {

        var imageBounds = NSZeroRect ; imageBounds.size = self.size
        let pathBounds = NSBezierPath(rect: imageBounds)
        var transform = NSAffineTransform()
        transform.rotate(byDegrees: degrees)
        pathBounds.transform(using: transform as AffineTransform)
        let rotatedBounds:CGRect = NSMakeRect(NSZeroPoint.x, NSZeroPoint.y , self.size.width, self.size.height )
        let rotatedImage = NSImage(size: rotatedBounds.size)

        //Center the image within the rotated bounds
        imageBounds.origin.x = NSMidX(rotatedBounds) - (NSWidth(imageBounds) / 2)
        imageBounds.origin.y  = NSMidY(rotatedBounds) - (NSHeight(imageBounds) / 2)

        // Start a new transform
        transform = NSAffineTransform()
        // Move coordinate system to the center (since we want to rotate around the center)
        transform.translateX(by: +(NSWidth(rotatedBounds) / 2 ), yBy: +(NSHeight(rotatedBounds) / 2))
        transform.rotate(byDegrees: degrees)
        // Move the coordinate system bak to normal
        transform.translateX(by: -(NSWidth(rotatedBounds) / 2 ), yBy: -(NSHeight(rotatedBounds) / 2))
        // Draw the original image, rotated, into the new image
        rotatedImage.lockFocus()
        transform.concat()
        self.draw(in: imageBounds, from: NSZeroRect, operation: .copy, fraction: 1.0)
        rotatedImage.unlockFocus()

        return rotatedImage
    }
}


extension ZFiles {
    
    
    func showInFinder() {
        (directoryURL as NSURL).open()
    }

    
    func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "mine.thoughtful"
        panel.begin { (response: NSApplication.ModalResponse) in
            if  let path = panel.url?.path {
                self.needWrite(for: .mineID)
                self.writeFile(at: path, from: .mineID)
            }
        }
    }

    
    class func presentOpenPanel(_ callback: AnyClosure? = nil) {
        if  let  window = gApplication.mainWindow {
            let   panel = NSOpenPanel()

            callback?(panel)

            panel.resolvesAliases               = true
            panel.canChooseDirectories          = false
            panel.canResolveUbiquitousConflicts = false
            panel.canDownloadUbiquitousContents = false
            
            panel.beginSheetModal(for: window) { (result) in
                if  result.rawValue == NSFileHandlingPanelOKButton,
                    panel.urls.count > 0 {
                    let url = panel.urls[0]
                    
                    callback?(url)
                }
            }
        }
    }
    
    
    func importFromFile(asOutline: Bool, insertInto: Zone, onCompletion: Closure?) {
        if !asOutline {
            ZFiles.presentOpenPanel() { (iAny) in
                if  let url = iAny as? URL {
                    self.importFile(from: url.path, insertInto: insertInto, onCompletion: onCompletion)
                } else if let panel = iAny as? NSPanel {
                    let  suffix = asOutline ? "outline" : "thoughtful"
                    panel.title = "Import as \(suffix)"
                    panel.setAllowedFileType(suffix)
                }
            }
        }
    }
    
    
    func importFile(from path: String, insertInto: Zone, onCompletion: Closure?) {
        do {
            if  let   data = FileManager.default.contents(atPath: path),
                data.count > 0,
                let   dbID = insertInto.databaseID,
                let   json = try JSONSerialization.jsonObject(with: data) as? [String : NSObject] {
                let   dict = self.dictFromJSON(json)
                let   zone = Zone(dict: dict, in: dbID)
                
                insertInto.addChild(zone, at: 0)
                onCompletion?()
            }
        } catch {
            print(error)    // de-serialization
        }
    }
    
    
    func exportToFile(asOutline: Bool, for iFocus: Zone) {
        let    suffix = asOutline ? "outline" : "thoughtful"
        let     panel = NSSavePanel()
        panel.message = "Export as \(suffix)"
        
        if  let  name = iFocus.zoneName {
            panel.nameFieldStringValue = "\(name).\(suffix)"
        }
        
        panel.begin { (result) -> Void in
            if  result.rawValue == NSFileHandlingPanelOKButton,
                let filename = panel.url {
                
                if  asOutline {
                    let string = iFocus.outlineString()
                    
                    do {
                        try string.write(to: filename, atomically: true, encoding: String.Encoding.utf8)
                    } catch {
                        // failed to write file (bad permissions, bad filename etc.)
                    }
                } else {
                    self.writtenRecordNames.removeAll()
                    
                    let     dict = iFocus.storageDictionary
                    let jsonDict = self.jsonDictFrom(dict)
                    let     data = try! JSONSerialization.data(withJSONObject: jsonDict, options: .prettyPrinted)
                    
                    do {
                        try data.write(to: filename)
                    } catch {
                        print("ahah")
                    }
                }
            }
        }
    }

}


extension Zone {


    func hasZoneAbove(_ iAbove: Bool) -> Bool {
        if  let index = siblingIndex {
            return index != (iAbove ? 0 : (parentZone!.count - 1))
        }

        return false
    }
    
}


extension ZoneWidget {


    func dragHitFrame(in iView: ZView?, _ iHere: Zone) -> CGRect {
        if  let   view = iView,
            let    dot = dragDot.innerDot {
            let isHere = widgetZone == iHere
            let cFrame =     convert(childrenView.frame, to: view)
            let dFrame = dot.convert(        dot.bounds, to: view)
            let   left =    isHere ? 0.0 : dFrame.minX - gGenericOffset.width
            let bottom =  (!isHere && widgetZone?.hasZonesBelow ?? false) ? cFrame.minY : 0.0
            let    top = ((!isHere && widgetZone?.hasZonesAbove ?? false) ? cFrame      : view.bounds).maxY
            let  right =                                                                  view.bounds .maxX

            return CGRect(x: left, y: bottom, width: right - left, height: top - bottom)
        }

        return CGRect.zero
    }


    func lineRect(to targetFrame: CGRect, kind: ZLineKind?) -> CGRect {
        var             frame = CGRect ()

        if  let     sourceDot = revealDot.innerDot, kind != nil {
            let   sourceFrame = sourceDot.convert( sourceDot.bounds, to: self)
            let     thickness = CGFloat(gLineThickness)
            let     dotHeight = CGFloat(gDotHeight)
            let halfDotHeight = dotHeight / 2.0
            let thinThickness = thickness / 2.0
            let    targetMidY = targetFrame.midY
            let    sourceMidY = sourceFrame.midY
            frame.origin   .x = sourceFrame.midX

            switch kind! {
            case .above:
                frame.origin   .y = sourceFrame.maxY
                frame.size.height = abs(  targetMidY + thinThickness - frame.minY)
            case .below:
                frame.origin   .y = targetFrame.minY + halfDotHeight - thickness  - thinThickness
                frame.size.height = abs(  sourceMidY - frame.minY - halfDotHeight + 2.0) // + thinThickness
            case .straight:
                frame.origin   .y =       targetMidY - thinThickness / 2.0
                frame.origin   .x = sourceFrame.maxX
                frame.size.height =                    thinThickness
            }

            frame.size     .width = abs(targetFrame.minX - frame.minX)
        }
        
        return frame
    }


    func curvedPath(in iRect: CGRect, kind iKind: ZLineKind) -> ZBezierPath {
        ZBezierPath(rect: iRect).setClip()

        let      dotHeight = CGFloat(gDotHeight)
        let   halfDotWidth = CGFloat(gDotWidth) / 2.0
        let  halfDotHeight = dotHeight / 2.0
        let        isAbove = iKind == .above
        var           rect = iRect

        if isAbove {
            rect.origin.y -= rect.height + halfDotHeight
        }

        rect.size   .width = rect.width  * 2.0 + halfDotWidth
        rect.size  .height = rect.height * 2.0 + (isAbove ? halfDotHeight : dotHeight)

        return ZBezierPath(ovalIn: rect)
    }
}


var gShortcutsController: ZWindowController?


extension ZGraphEditor {


    func showHideKeyboardShortcuts(hide: Bool? = nil) {
        if  gShortcutsController == nil {
            let       storyboard  = NSStoryboard(name: "Shortcuts", bundle: nil)
            gShortcutsController  = storyboard.instantiateInitialController() as? NSWindowController
        }
        
        if  let notShow = hide {
            gShowShortcutWindow = !notShow
        } else {
            gShowShortcutWindow = !(gShortcutsController?.window?.isKeyWindow ?? false)
        }
        
        if  gShowShortcutWindow {
            gShortcutsController?.showWindow(nil)
        } else {
            gShortcutsController?.window?.close()
        }
    }

}


extension ZOnboarding {
    
    func getMAC() {
        if let intfIterator = findEthernetInterfaces() {
            if  let macAddressAsArray = getMACAddress(intfIterator) {
                let macAddressAsString = macAddressAsArray.map( { String(format:"%02x", $0) } )
                    .joined(separator: kSeparator)
                macAddress = macAddressAsString
            }
            
            IOObjectRelease(intfIterator)
        }
    }
    
    
    func findEthernetInterfaces() -> io_iterator_t? {
        
        let matchingDict = IOServiceMatching("IOEthernetInterface") as NSMutableDictionary
        matchingDict["IOPropertyMatch"] = [ "IOPrimaryInterface" : true]
        
        var matchingServices : io_iterator_t = 0
        if IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &matchingServices) != KERN_SUCCESS {
            return nil
        }
        
        return matchingServices
    }
    
    
    func getMACAddress(_ intfIterator : io_iterator_t) -> [UInt8]? {
        
        var macAddress : [UInt8]?
        
        var intfService = IOIteratorNext(intfIterator)
        while intfService != 0 {
            
            var controllerService : io_object_t = 0
            if IORegistryEntryGetParentEntry(intfService, "IOService", &controllerService) == KERN_SUCCESS {
                
                let dataUM = IORegistryEntryCreateCFProperty(controllerService, "IOMACAddress" as CFString, kCFAllocatorDefault, 0)
                if let data = dataUM?.takeRetainedValue() as? NSData {
                    macAddress = [0, 0, 0, 0, 0, 0]
                    data.getBytes(&macAddress!, length: macAddress!.count)
                }
                IOObjectRelease(controllerService)
            }
            
            IOObjectRelease(intfService)
            intfService = IOIteratorNext(intfIterator)
        }
        
        return macAddress
    }

}
