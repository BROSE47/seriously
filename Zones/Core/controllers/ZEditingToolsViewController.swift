//
//  ZEditingToolsViewController.swift
//  Zones
//
//  Created by Jonathan Sand on 10/10/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZEditingToolsViewController: ZGenericViewController {


    @IBOutlet weak var                  newZoneButton: ZButton!
    @IBOutlet weak var               deleteZoneButton: ZButton!
    @IBOutlet weak var               moveZoneUpButton: ZButton!
    @IBOutlet weak var             moveZoneDownButton: ZButton!
    @IBOutlet weak var         moveZoneToParentButton: ZButton!
    @IBOutlet weak var moveZoneIntoSiblingAboveButton: ZButton!


    @IBAction func genericButtonAction(_ button: ZButton) {
        zonesManager.takeAction(ZEditAction(rawValue: UInt(button.tag))!)
    }


    override func update() {
        let         zone = zonesManager.currentlyMovableZone
        let hasSelection = zone != nil
        let   parentZone = zone?.parentZone
        let     children = parentZone?.children
        let  hasSiblings = parentZone != nil && (children?.count)! > 1
        let        atTop = (children?.first == zone)
        let     atBottom = (children?.last  == zone)

        deleteZoneButton  .isHidden = !hasSelection || !zonesManager.canDelete
        moveZoneUpButton  .isHidden = !hasSelection || !hasSiblings || atTop
        moveZoneDownButton.isHidden = !hasSelection || !hasSiblings || atBottom
    }
}
