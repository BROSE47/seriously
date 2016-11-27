//
//  ZoneWindow.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif




class ZoneWindow: ZWindow {


    static var window: ZoneWindow?
    override var acceptsFirstResponder: Bool { get { return true } }


    override func awakeFromNib() {
        super.awakeFromNib()

        ZoneWindow.window = self
    }


    override func keyDown(with event: ZEvent) {
        if selectionManager.currentlyEditingZone != nil || !editingManager.handleKey(event, isWindow: true) {
            super.keyDown(with: event)
        }
    }
}