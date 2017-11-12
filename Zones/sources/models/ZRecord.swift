//
//  ZRecord.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZRecord: NSObject {
    

    var    storageMode: ZStorageMode?
    var     kvoContext: UInt8 = 1
    var        _record: CKRecord?
    var         isRoot: Bool            { return record != nil && [gRootNameKey, gFavoriteRootNameKey, gTrashNameKey].contains(record.recordID.recordName) }
    var      needsSave: Bool            { return isMarkedForAnyOfStates([.needsSave]) }
    var      needsRoot: Bool            { return isMarkedForAnyOfStates([.needsRoot]) }
    var     needsCount: Bool            { return isMarkedForAnyOfStates([.needsCount]) }
    var     needsColor: Bool            { return isMarkedForAnyOfStates([.needsColor]) }
    var     needsFetch: Bool            { return isMarkedForAnyOfStates([.needsFetch]) }
    var    needsCreate: Bool            { return isMarkedForAnyOfStates([.needsCreate]) }
    var    needsParent: Bool            { return isMarkedForAnyOfStates([.needsParent]) }
    var   needsDestroy: Bool            { return isMarkedForAnyOfStates([.needsDestroy]) }
    var   needsProgeny: Bool            { return isMarkedForAnyOfStates([.needsProgeny]) }
    var  needsWritable: Bool            { return isMarkedForAnyOfStates([.needsWritable]) }
    var  needsChildren: Bool            { return isMarkedForAnyOfStates([.needsChildren]) }
    var needsBookmarks: Bool            { return isMarkedForAnyOfStates([.needsBookmarks]) }
    var recordsManager: ZRecordsManager { return gRemoteStoresManager.recordsManagerFor(storageMode!) }
    var   cloudManager: ZCloudManager?  { return recordsManager as? ZCloudManager }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if  _record != newValue {
                _record  = newValue

                register()
                updateInstanceProperties()
                setupLinks()
            }
        }
    }


    var alreadyExists: Bool {
        if  let    r = record {
            return r.creationDate != nil
        }

        return false
    }


    var storageDict: ZStorageDict {
        get {
            return storageDictionary()!
        }

        set {
            if newValue.count > 0 {
                setStorageDictionary(newValue)
            }
        }
    }


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()

        self.storageMode = nil
        self.record      = nil

        self.setupKVO();
    }


    convenience init(record: CKRecord?, storageMode: ZStorageMode?) {
        self.init()

        self.storageMode = storageMode

        if record != nil {
            self.record = record
        }
    }


    deinit {
        teardownKVO()
    }


    func register() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }


    // MARK:- properties
    // MARK:-


    func setupLinks() {}


    func updateInstanceProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if  let    cloudValue = record[keyPath] as! NSObject? {
                    let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                    if propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateRecordProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                let    cloudValue = record[keyPath] as! NSObject?
                let propertyValue = value(forKeyPath: keyPath) as! NSObject?

                if propertyValue != nil && propertyValue != cloudValue {
                    record[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }


    func copy(into copy: ZRecord) {
        copy.needFlush() // so KVO won't call set needsMerge state bit
        updateRecordProperties()

        for keyPath: String in cloudProperties() {
            copy.record[keyPath] = record[keyPath]
        }

        copy.updateInstanceProperties()
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateRecordProperties()

        if record != nil {
            for keyPath: String in cloudProperties() {
                iRecord[keyPath] = record[keyPath]
            }
        }

        record = iRecord

        needFlush()
    }


    func setStorageDictionary(_ dict: ZStorageDict) {
        storageMode       = gStorageMode
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case gRecordTypeKey: type = value as? String; break
            case gRecordNameKey: name = value as? String; break
            default:                                     break
            }
        }

        if type != nil && name != nil {
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

            self.updateRecordProperties()

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return record == nil ? [:] :
            [gRecordNameKey : record.recordID.recordName as NSObject,
             gRecordTypeKey : record.recordType          as NSObject]
    }


    // MARK:- states
    // MARK:-


    func isMarkedForAnyOfStates(_ states: [ZRecordState]) -> Bool { return recordsManager.hasRecord(self, forAnyOf:states) }
    func markForAllOfStates    (_ states: [ZRecordState])         {        recordsManager.addRecord(self, for: states) }
    func clearAllStates()                                         {        recordsManager.clearAllStatesForRecord(self.record) }


    func unmarkForAllOfStates(_ states: [ZRecordState]) {
        if let identifier = self.record?.recordID {
            recordsManager.clearStatesForRecordID(identifier, forStates:states)
        }
    }


    func needSave()      { markForAllOfStates([.needsSave]) }
    func needRoot()      { markForAllOfStates([.needsRoot]) }
    func needCount()     { markForAllOfStates([.needsCount]) }
    func needColor()     { markForAllOfStates([.needsColor]) }
    func needFetch()     { markForAllOfStates([.needsFetch]) }
    func needCreate()    { markForAllOfStates([.needsCreate]) }
    func needParent()    { markForAllOfStates([.needsParent]) }
    func needDestroy()   { markForAllOfStates([.needsDestroy]); unmarkForAllOfStates([.needsSave, .needsCreate]) }
    func needProgeny()   { markForAllOfStates([.needsProgeny]) }
    func needWritable()  { markForAllOfStates([.needsWritable]) }
    func needChildren()  { markForAllOfStates([.needsChildren]) }
    func needBookmarks() { markForAllOfStates([.needsBookmarks]) }


    func needFlush() {
        if  storageMode != .favoritesMode {
            markForAllOfStates([alreadyExists ? .needsSave : .needsCreate]);
            unmarkForAllOfStates([.needsMerge])
        }
    }


    func maybeNeedMerge() {
        if !isMarkedForAnyOfStates([.needsCreate, .needsSave, .needsMerge]) {
            markForAllOfStates([.needsMerge])
        }
    }


    // MARK:- accessors and KVO
    // MARK:-


    func setValue(_ value: NSObject, for property: String) {
        cloudManager?.setIntoObject(self, value: value, for: property)
    }


    func get(propertyName: String) {
        cloudManager?.getFromObject(self, valueForPropertyName: propertyName)
    }


    func teardownKVO() {
        for keyPath: String in cloudProperties() {
            removeObserver(self, forKeyPath: keyPath)
        }
    }


    func setupKVO() {
        for keyPath: String in cloudProperties() {
            addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }


    override func observeValue(forKeyPath keyPath: String?, of iObject: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observer = iObject as! NSObject

            if let value: NSObject = observer.value(forKey: keyPath!) as! NSObject? {
                setValue(value, for: keyPath!)
            }
        }
    }
}
