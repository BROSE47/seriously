//
//  ZEditorViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import SnapKit


class ZEditorViewController: ZGenericViewController {

    
    var widget: ZoneWidget = ZoneWidget()


    override func identifier() -> ZControllerID { return .editor }


    override func updateFor(_ object: NSObject?, kind: ZUpdateKind) {
        var specificWidget: ZoneWidget? = widget
        var specificView:        ZView? = view
        var specificindex:          Int = -1
        var recursing:             Bool = kind == .data
        widget.widgetZone               = zonesManager.rootZone!

        if object == nil || object == zonesManager.rootZone! {
            recursing = true

            print("all")
            zonesManager.clearWidgets()
        } else {
            let       zone = object as! Zone
            specificWidget = zonesManager.widgetForZone(zone)
            specificView   = specificWidget?.superview
            specificindex  = zone.siblingIndex()

            if let name = zone.zoneName {
                print(name)
            }
        }

        specificWidget?.layoutInView(specificView, atIndex: specificindex, recursing: recursing)
        specificWidget?.updateConstraints()
        specificWidget?.layoutFinish()
        specificWidget?.display()

        stateManager.textCapturing = false
    }


    override func setup() {
        view.setupGestures(self, action: #selector(ZEditorViewController.gestureEvent))
        super.setup()
    }

    
    func gestureEvent(_ sender: ZGestureRecognizer?) {
        zonesManager.deselect()
    }
}