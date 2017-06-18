//
//  ZPreferencesController.swift
//  Zones
//
//  Created by Jonathan Sand on 4/13/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


class ZPreferencesController: ZGenericController {


    @IBOutlet var        countsModeControl: ZSegmentedControl?
    @IBOutlet var graphAlteringModeControl: ZSegmentedControl?
    @IBOutlet var             zoneColorBox: ZColorWell?
    @IBOutlet var         bookmarkColorBox: ZColorWell?
    @IBOutlet var       backgroundColorBox: ZColorWell?
    @IBOutlet var      dragTargetsColorBox: ZColorWell?
    @IBOutlet var        horizontalSpacing: ZSlider?
    @IBOutlet var          verticalSpacing: ZSlider?
    @IBOutlet var                thickness: ZSlider?
    @IBOutlet var        removeColorButton: NSButton?


    override func identifier() -> ZControllerID { return .preferences }


    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        let                               grabbed = gSelectionManager.firstGrab
        view              .zlayer.backgroundColor = CGColor.clear
        graphAlteringModeControl?.selectedSegment = gGraphAlteringMode.rawValue
        countsModeControl?       .selectedSegment = gCountsMode.rawValue
        thickness?                   .doubleValue = gLineThickness
        verticalSpacing?             .doubleValue = Double(gGenericOffset.height)
        horizontalSpacing?           .doubleValue = Double(gGenericOffset.width)
        dragTargetsColorBox?               .color = gDragTargetsColor
        backgroundColorBox?                .color = gBackgroundColor
        bookmarkColorBox?                  .color = gBookmarkColor
        zoneColorBox?                      .color =  grabbed.color
        removeColorButton?              .isHidden = !grabbed.hasColor
    }


    // MARK:- actions
    // MARK:-


    @IBAction func sliderAction(_ iSlider: ZSlider) {
        let value = CGFloat(iSlider.doubleValue)

        if  let     identifier = iSlider.identifier {
            switch (identifier) {
            case  "thickness": gLineThickness = Double(value)
            case "horizontal": gGenericOffset = CGSize(width: value, height: gGenericOffset.height)
            case   "vertical": gGenericOffset = CGSize(width: gGenericOffset.width, height: value)
            default:           break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func colorBoxAction(_ iColorBox: ZColorWell) {
        let color = iColorBox.color

        if  let     identifier = iColorBox.identifier {
            switch (identifier) {
            case "drag targets":                 gDragTargetsColor = color
            case   "background":                  gBackgroundColor = color
            case    "bookmarks":                    gBookmarkColor = color
            case        "zones": gSelectionManager.firstGrab.color = color
            default:             break
            }

            signalFor(nil, regarding: .redraw)
        }
    }


    @IBAction func removeColorAction(_ button: NSButton) {
        let grab = gSelectionManager.firstGrab

        grab.removeColor()
        syncToCloudAndSignalFor(grab, regarding: .redraw) {}
    }


    @IBAction func countsModeAction(_ iControl: ZSegmentedControl) {
        gCountsMode = ZCountsMode(rawValue: iControl.selectedSegment)!

        signalFor(nil, regarding: .data)
    }


    @IBAction func graphAlteringModeAction(_ iControl: ZSegmentedControl) {
        gGraphAlteringMode = ZGraphAlteringMode(rawValue: iControl.selectedSegment)!

        signalFor(nil, regarding: .data)
    }


}
