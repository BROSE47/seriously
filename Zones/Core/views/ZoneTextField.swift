//
//  ZoneTextField.swift
//  Zones
//
//  Created by Jonathan Sand on 10/27/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZoneTextField: ZTextField, ZTextFieldDelegate {


    var widget: ZoneWidget!
    var isEditing: Bool = false
    var monitor: Any?


    func setup() {
        font                   = widgetFont
        delegate               = self
        isBordered             = false
        textAlignment          = .center
        backgroundColor        = ZColor.clear
        zlayer.backgroundColor = ZColor.clear.cgColor
    }


    func toggleResponderState() {
        if isEditing {
            resignFirstResponder()
        } else {
            becomeFirstResponder()
        }
    }


    @discardableResult override func resignFirstResponder() -> Bool {
        captureText()

        if let save = monitor {
            dispatchAsyncInForeground {
                ZEvent.removeMonitor(save)
            }
        }

        isEditing = false
        monitor   = nil

        return super.resignFirstResponder()
    }


    @discardableResult override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        isEditing  = true

        if result {
            selectionManager.currentlyEditingZone = widget.widgetZone
            controllersManager.updateToClosures(widget.widgetZone, regarding: .datum)

            monitor = ZEvent.addLocalMonitorForEvents(matching: .keyDown, handler: {(event) -> NSEvent? in
                mainWindow?.handleKey(event)

                return event
            })
        }

        return result
    }


    func captureText() {
        if  stateManager.textCapturing    == false {
            if widget.widgetZone.zoneName != text! {
                stateManager.textCapturing = true
                widget.widgetZone.zoneName = text!
            }
        }
    }
    

#if os(OSX)

    // fix a bug where root zone is editing on launch
    override var acceptsFirstResponder: Bool { get { return operationsManager.isReady } }


    override func controlTextDidEndEditing(_ obj: Notification) {
        captureText()
        dispatchAsyncInForeground {
            self.resignFirstResponder()
            selectionManager.fullResign()
        }
    }


    func stopEditing() {
        if currentEditor() != nil {
            resignFirstResponder()
        }
    }


    override func controlTextDidChange(_ obj: Notification) {
        widget.layoutTextField()
    }

#elseif os(iOS)

    // fix a bug where root zone is editing on launch
    override var canBecomeFirstResponder: Bool { get { return operationsManager.isReady } }
    

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        captureText()

        return true
    }


    func stopEditing() {
        resignFirstResponder()
    }

#endif
}
