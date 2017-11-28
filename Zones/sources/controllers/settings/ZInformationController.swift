//
//  ZInformationController.swift
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


class ZInformationController: ZGenericController {


    override  var     controllerID: ZControllerID { return .information }
    @IBOutlet var fractionInMemory: ZProgressIndicator?
    @IBOutlet var  totalCountLabel: ZTextField?
    @IBOutlet var   graphNameLabel: ZTextField?
    @IBOutlet var     versionLabel: ZTextField?
    @IBOutlet var       levelLabel: ZTextField?


    var statusText: String {
        if  let     version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion")            as? String {
            return "version \(version), build \(buildNumber)"
        }

        return ""
    }


    override func awakeFromNib() {
        view.zlayer.backgroundColor = CGColor.clear
        fractionInMemory? .minValue = 0
    }

    override func handleSignal(_ object: Any?, in storageMode: ZStorageMode, kind: ZSignalKind) {
        if ![.search, .found].contains(kind) {
            let                     count = gRemoteStoresManager.recordsManagerFor(storageMode).undeletedCount
            let                     total = gRemoteStoresManager.rootProgenyCount // TODO wrong manager
            totalCountLabel?        .text = "of \(total), retrieved: \(count)"
            graphNameLabel?         .text = "graph: \(gStorageMode.rawValue)"
            fractionInMemory?.doubleValue = Double(count)
            fractionInMemory?   .maxValue = Double(total)
            versionLabel?           .text = statusText

            if kind != .startup {
                levelLabel?         .text = "level: \(gSelectionManager.rootMostMoveable.level)"
            }
        }
    }
}
