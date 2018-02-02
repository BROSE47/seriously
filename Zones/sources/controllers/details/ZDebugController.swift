//
//  ZDebugController.swift
//  Zones
//
//  Created by Jonathan Sand on 1/16/18.
//  Copyright © 2018 Zones. All rights reserved.
//

import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZDebugController: ZGenericController {


    @IBOutlet var   nameLabel: ZTextField?
    @IBOutlet var  otherLabel: ZTextField?
    @IBOutlet var statusLabel: ZTextField?
    @IBOutlet var recordLabel: ZTextField?
    var grab: Zone? = nil


    var statusText: String {
        var text = " "

        if  let zone = grab {
            let count = zone.fetchableCount

            text.append(zone.alreadyExists ? "F " : "! ")

            if zone.parent != nil {
                text.append("P ")
            } else if zone.name(from: zone.parentLink) != nil {
                text.append("L ")
            }

            if zone.showChildren {
                text.append("S ")
            }

            if count != 0 {
                text.append("\(count) ")
            }
        }

        return text
    }


    var otherText: String {
        var text = ""

        if  let zone = grab {
            let order = Double(Int(zone.order * 100)) / 100.0

            text.append("\(order)")
        }

        if let debugView = view.window?.contentView {
//        if let gEditorController!.editorRootWidget {
//        if let view.window!.contentView {
//        if let gEditorView {

            text.append(" \(debugView.bounds.size)")
        }

        return text
    }


    override func setup() {
        controllerID = .debug
    }


    override func handleSignal(_ object: Any?, iKind: ZSignalKind) {
        if ![.search, .found].contains(iKind) && gReadyState {
            grab              = gSelectionManager.firstGrab
            nameLabel?  .text = grab?.unwrappedName
            recordLabel?.text = grab?.recordName
            otherLabel? .text = otherText
            statusLabel?.text = statusText
        }
    }
    
}
