//
//  ZSettingsController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import SnapKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZSliderKind: String {
    case Vertical   = "vertical"
    case Thickness  = "thickness"
    case Horizontal = "horizontal"
}


enum ZColorBoxKind: String {
    case Zones       = "zones"
    case Bookmarks   = "bookmarks"
    case Background  = "background"
    case DragTargets = "drag targets"
}


struct ZSettingsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZSettingsViewID(rawValue: 1 << 0)
    static let Preferences = ZSettingsViewID(rawValue: 1 << 1)
    static let   Favorites = ZSettingsViewID(rawValue: 1 << 2)
    static let       Cloud = ZSettingsViewID(rawValue: 1 << 3)
    static let        Help = ZSettingsViewID(rawValue: 1 << 4)
    static let         All = ZSettingsViewID(rawValue: 0xFFFF)
}


class ZSettingsController: ZGenericController {

    
    override func identifier() -> ZControllerID { return .settings }


    func displayViewFor(id: ZSettingsViewID) {
        let type = ZStackableView.self.className()

        gSettingsViewIDs.insert(id)
        view.applyToAllSubviews { (iView: ZView) in
            if  iView.className == type, let stackView = iView as? ZStackableView {
                stackView.update()
            }
        }
    }

}