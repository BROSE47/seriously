//
//  Zone.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


struct ZoneState: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let ShowsChildren = ZoneState(rawValue: 1 <<  0)
    static let   HasChildren = ZoneState(rawValue: 1 <<  1)
    static let    IsFavorite = ZoneState(rawValue: 1 << 29)
    static let     IsDeleted = ZoneState(rawValue: 1 << 30)
}


class Zone : ZRecord {


    dynamic var  zoneName:      String?
    dynamic var  zoneLink:      String?
    dynamic var    parent: CKReference?
    dynamic var zoneOrder:    NSNumber?
    dynamic var zoneState:    NSNumber?
    dynamic var zoneLevel:    NSNumber?
    var          children      = [Zone] ()
    var       _parentZone:        Zone?
    var        _crossLink:     ZRecord?
    var        isBookmark:         Bool { get { return crossLink != nil } }


    // MARK:- properties
    // MARK:-


    class func cloudProperties() -> [String] {
        return [#keyPath(parent),
                #keyPath(zoneName),
                #keyPath(zoneLink),
                #keyPath(zoneOrder),
                #keyPath(zoneState),
                #keyPath(zoneLevel)]
    }


    var crossLink: ZRecord? {
        get {
            if zoneLink == "" {
                return nil
            } else if _crossLink == nil {
                let components: [String] = (zoneLink?.components(separatedBy: ":"))!
                let refString:   String  = components[2] == "" ? "root" : components[2]
                let refID:    CKRecordID = CKRecordID(recordName: refString)
                let refRecord:  CKRecord = CKRecord(recordType: zoneTypeKey, recordID: refID)
                let mode:  ZStorageMode? = ZStorageMode(rawValue: components[0])

                _crossLink = ZRecord(record: refRecord, storageMode: mode)
            }

            return _crossLink
        }

        set {
            if newValue == nil {
                zoneLink = nil
            } else {
                let    hasRef = newValue != nil && newValue!.record != nil
                let reference = !hasRef ? "" : newValue!.record.recordID.recordName
                zoneLink      = "\(newValue!.storageMode!.rawValue)::\(reference)"
            }

            _crossLink = nil
        }
    }


    var order: Double {
        get {
            if zoneOrder == nil {
                updateZoneProperties()

                if zoneOrder == nil {
                    zoneOrder = NSNumber(value: 0.0)
                }
            }

            return Double((zoneOrder?.doubleValue)!)
        }

        set {
            if newValue != order {
                zoneOrder = NSNumber(value: newValue)

                self.maybeNeedMerge()
            }
        }
    }


    var level: Int {
        get {
            if zoneLevel == nil {
                updateZoneProperties()

                if zoneLevel == nil {
                    zoneLevel = NSNumber(value: unlevel)
                }
            }

            return (zoneLevel?.intValue)!
        }

        set {
            if newValue != level {
                zoneLevel = NSNumber(value: newValue)

                self.maybeNeedMerge()
            }
        }
    }


    var state: ZoneState {
        get {
            if zoneState == nil {
                updateZoneProperties()

                if zoneState == nil {
                    zoneState = NSNumber(value: 1)
                }
            }

            return ZoneState(rawValue: Int((zoneState?.int64Value)!))
        }

        set {
            if newValue != state {
                zoneState = NSNumber(integerLiteral: newValue.rawValue)
                
                self.maybeNeedMerge()
            }
        }
    }


    var isDeleted: Bool {
        get {
            return state.contains(.IsDeleted)
        }

        set {
            if newValue != isDeleted {
                if newValue {
                    state.insert(.IsDeleted)
                } else {
                    state.remove(.IsDeleted)
                }
            }
        }
    }


    var isFavorite: Bool {
        get {
            return state.contains(.IsFavorite)
        }

        set {
            if newValue != isFavorite {
                if newValue {
                    state.insert(.IsFavorite)
                } else {
                    state.remove(.IsFavorite)
                }
            }
        }
    }


    var hasChildren: Bool {
        get {
            return state.contains(.HasChildren)
        }

        set {
            if newValue != hasChildren {
                if newValue {
                    state.insert(.HasChildren)
                } else {
                    state.remove(.HasChildren)
                }
            }
        }
    }


    var showChildren: Bool {
        get {
            return state.contains(.ShowsChildren)
        }

        set {
            if newValue != showChildren {
                if newValue {
                    state.insert(.ShowsChildren)
                } else {
                    state.remove(.ShowsChildren)
                }
            }
        }
    }

    
    var parentZone: Zone? {
        get {
            if parent == nil && _parentZone?.record != nil {
                needSave()

                parent          = CKReference(record: (_parentZone?.record)!, action: .none)
            }

            if parent != nil && _parentZone == nil {
                _parentZone     = cloudManager.zoneForReference(parent!) // sometimes yields nil ... WHY?
            }

            return _parentZone
        }

        set {
            _parentZone  = newValue

            if let parentRecord = newValue?.record {
                parent          = CKReference(record: parentRecord, action: .none)
            } else {
                parent          = nil
            }
        }
    }


    static func == ( left: Zone, right: Zone) -> Bool {
        let unequal = left != right // avoid infinite recursion by using negated version of this infix operator

        if  unequal && left.record != nil && right.record != nil {
            return left.record.recordID.recordName == right.record.recordID.recordName
        }

        return !unequal
    }

    subscript(i: Int) -> Zone? {
        if i < children.count && i >= 0 {
            return children[i]
        } else {
            return nil
        }
    }


    func deepCopy() -> Zone {
        let          zone = Zone(record: nil, storageMode: gStorageMode)
        zone.showChildren = showChildren
        zone.crossLink    = crossLink
        zone.zoneName     = zoneName
        zone.order        = order

        for child in children {
            zone.children.append(child.deepCopy())
        }

        return zone
    }


    override func register() {
        cloudManager.registerZone(self)
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + Zone.cloudProperties()
    }


    override func updateZoneProperties() {
        super.updateZoneProperties()

        if zoneLink == nil {
            zoneLink = ""

            needSave()
        }
    }

    
    // MARK:- offspring
    // MARK:-


    override func needChildren() {
        if children.count == 0 {
            // report("need children of \(zoneName!)")
            super.needChildren()
        }
    }


    func orphan() {
        parentZone?.removeChild(self)
        needSave()

        parentZone = nil
        parent     = nil
    }


    func addChild(_ child: Zone?, at index: Int) {
        if child != nil {
            hasChildren = true

            if children.contains(child!) {
                return
            }

            // make sure it's not already been added
            // NOTE: both must have a record for this to be effective

            if child?.record != nil {
                let identifier = child?.record.recordID.recordName

                for sibling in children {
                    if sibling.record != nil && sibling.record.recordID.recordName == identifier {
                        return
                    }
                }
            }

            child?.updateLevel()

            children.insert(child!, at: index)
        }
    }


    func addChild(_ child: Zone?) {
        addChild(child, at: 0)
    }


    func removeChild(_ child: Zone?) {
        if child != nil, let index = children.index(of: child!) {
            children.remove(at: index)
            child!.orphan()
            needSave()

            if children.count == 0 {
                hasChildren = false
            }
        }
    }


    func orderAt(_ index: Int) -> Double? {
        if index >= 0 && index < children.count {
            let child = children[index]

            return child.order
        }

        return nil
    }


    func respectOrder() {
        children.sort { (a, b) -> Bool in
            return a.order < b.order
        }
    }


    func normalizeOrdering() {
        let increment = 1.0 / Double(children.count + 2)

        for (index, child) in children.enumerated() {
            child.order = increment * Double(index + 1)
        }
    }


    func recomputeOrderingUponInsertionAt(_ index: Int) {
        let  orderLarger = orderAt(index + 1) ?? 1.0
        let orderSmaller = orderAt(index - 1) ?? 0.0
        let        child = children[index]
        child.order      = (orderLarger + orderSmaller) / 2.0
    }


    var siblingIndex: Int? {
        get {
            if let siblings: [Zone] = parentZone?.children, let index = siblings.index(of: self) {
                return index
            }

            return nil
        }
    }


    @discardableResult func traverseApply(_ block: ZoneToBooleanClosure) -> Bool {
        var stop = block(self)

        if !stop {
            for child in children {
                if child.traverseApply(block) {
                    stop = true

                    break
                }
            }
        }

        return stop
    }


    func updateLevel() {
        traverseApply { iZone -> Bool in
            if let parentLevel = iZone.parentZone?.level, parentLevel != unlevel {
                iZone.level = parentLevel + 1
            }

            return false
        }
    }


    // MARK:- file persistence
    // MARK:-


    convenience init(dict: ZStorageDict) {
        self.init(record: nil, storageMode: gStorageMode)

        storageDict = dict
    }

    
    override func setStorageDictionary(_ dict: ZStorageDict) {
        if let string = dict[    zoneNameKey] as!   String? { zoneName     = string }
        if let number = dict[showChildrenKey] as! NSNumber? { showChildren = number.boolValue }

        if let childrenStore: [ZStorageDict] = dict[childrenKey] as! [ZStorageDict]? {
            for childStore: ZStorageDict in childrenStore {
                let        child = Zone(dict: childStore)
                child.parentZone = self

                children.append(child)
            }

            respectOrder()
        }

        super.setStorageDictionary(dict) // do this step last so the assignment above is NOT pushed to cloud
    }


    override func storageDictionary() -> ZStorageDict? {
        var      childrenStore = [ZStorageDict] ()
        var               dict = super.storageDictionary()!
        dict[zoneNameKey]      = zoneName as NSObject?
        dict[showChildrenKey]  = NSNumber(booleanLiteral: showChildren)


        for child: Zone in children {
            childrenStore.append(child.storageDictionary()!)
        }

        dict[childrenKey]      = childrenStore as NSObject?

        return dict
    }
}
