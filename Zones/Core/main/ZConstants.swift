//
//  ZConstants.swift
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


enum ZSynchronizationState: Int {
    case restore
    case root
    case unsubscribe
    case subscribe
    case ready
}


enum ZUpdateKind: UInt {
    case data
    case error
    case delete
}


enum ZToolMode: Int {
    case edit
    case travel
    case layout
}


enum ZEditAction: UInt {
    case add
    case delete
    case moveUp
    case moveDown
}


let       stateManager = ZStateManager()
let       modelManager = ZModelManager()
let persistenceManager = ZLocalPersistenceManager()
let  widgetFont: ZFont = ZFont.systemFont(ofSize: 17.0)
let            cloudID = "iCloud.com.zones.Zones"
let    showChildrenKey = "showChildren"
let      recordNameKey = "recordName"
let      recordTypeKey = "recordType"
let        childrenKey = "children"
let        zoneNameKey = "zoneName"
let        zoneTypeKey = "Zone"
let        rootNameKey = "root"
let         parentsKey = "parents"
let           linksKey = "links"