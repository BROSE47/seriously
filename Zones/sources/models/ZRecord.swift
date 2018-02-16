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
    

    var           _record: CKRecord?
    var        databaseID: ZDatabaseID?
    var        kvoContext: UInt8 = 1
    var isRootOfFavorites: Bool             { return record != nil && recordName == kFavoritesRootName }
    var        isBookmark: Bool             { return record?.isBookmark ?? false }
    var            isRoot: Bool             { return record != nil && kRootNames.contains(recordName!) }
    var           canSave: Bool             { return !hasState(.requiresFetch) }
    var       isFromCloud: Bool             { return !hasState(.notFetched) }
    var         needsSave: Bool             { return  hasState(.needsSave) }
    var         needsRoot: Bool             { return  hasState(.needsRoot) }
    var        notFetched: Bool             { return  hasState(.notFetched) }
    var        needsCount: Bool             { return  hasState(.needsCount) }
    var        needsColor: Bool             { return  hasState(.needsColor) }
    var        needsFetch: Bool             { return  hasState(.needsFetch) }
    var        needsMerge: Bool             { return  hasState(.needsMerge) }
    var       needsTraits: Bool             { return  hasState(.needsTraits) }
    var       needsParent: Bool             { return  hasState(.needsParent) }
    var      needsDestroy: Bool             { return  hasState(.needsDestroy) }
    var      needsProgeny: Bool             { return  hasState(.needsProgeny) }
    var     needsWritable: Bool             { return  hasState(.needsWritable) }
    var     needsChildren: Bool             { return  hasState(.needsChildren) }
    var    needsBookmarks: Bool             { return  hasState(.needsBookmarks) }
    var    recordsManager: ZRecordsManager? { return gRemoteStoresManager.recordsManagerFor(databaseID) }
    var      cloudManager: ZCloudManager?   { return recordsManager as? ZCloudManager }
    var        recordName: String?          { return record?.recordID.recordName }


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if  _record != newValue {
                gBookmarksManager.unregisterBookmark(self as? Zone)
                cloudManager?.unregisterCKRecord(_record)

                _record  = newValue

                register()
                maybeFromCloud()
                updateInstanceProperties()
                setupLinks()

                let zone = self as? Zone
                let name = zone?.zoneName

                if       !canSave &&  isFromCloud {
                    columnarReport("ALLOW SAVE", name ?? recordName)
                    allowSave()
                } else if canSave && notFetched {
//                    columnarReport("DON'T SAVE", name ?? recordName)
                    requireFetch()

                    if name != nil || recordName == kRootName {
                        bam("named ... should allow saving")
                    }
                }
            }
        }
    }

    
    var showChildren: Bool  {
        var show = false

        if isRootOfFavorites {
            show = true
        } else {
            show = isExpanded(self.recordName)
        }

        return show
    }


    func isExpanded(_ iRecordName: String?) -> Bool {
        if  let name = iRecordName,
            let    _ = gExpandedZones.index(of: name) {
            return true
        }

        return false
    }


    func revealChildren() {
        var expansionSet = gExpandedZones

        if  let name = recordName, !isBookmark, !expansionSet.contains(name) {
            expansionSet.append(name)

            gExpandedZones = expansionSet
        }
    }


    func concealChildren() {
        var expansionSet = gExpandedZones

        if let  name = recordName {
            while let index = expansionSet.index(of: name) {
                expansionSet.remove(at: index)
            }
        }

        if  gExpandedZones.count != expansionSet.count {
            gExpandedZones        = expansionSet
        }
    }


    // MARK:- overrides
    // MARK:-


    override init() {
        super.init()

        self.databaseID = nil
        self.record      = nil

        self.setupKVO();
    }


    convenience init(record: CKRecord?, databaseID: ZDatabaseID?) {
        self.init()

        self.databaseID = databaseID

        if  let r = record {
            self.record = r
        }

        unorphan()
    }


    deinit {
        teardownKVO()
    }


    func unorphan() {}
    func maybeNeedRoot() {}
    func debug(_  iMessage: String) {}
    func cloudProperties() -> [String] { return [] }
    func   register() { cloudManager?  .registerZRecord(self) }
    func unregister() { cloudManager?.unregisterZRecord(self) }
    func hasMissingChildren() -> Bool { return false }
    func hasMissingProgeny()  -> Bool { return false }


    // MARK:- properties
    // MARK:-


    func setupLinks() {}


    func updateInstanceProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                if  let    cloudValue  = record[keyPath] as! NSObject? {
                    let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                    if  propertyValue != cloudValue {
                        setValue(cloudValue, forKeyPath: keyPath)
                    }
                }
            }
        }
    }


    func updateRecordProperties() {
        if record != nil {
            for keyPath in cloudProperties() {
                let    cloudValue  = record[keyPath] as! NSObject?
                let propertyValue  = value(forKeyPath: keyPath) as! NSObject?

                if  propertyValue != nil && propertyValue != cloudValue {
                    record[keyPath] = propertyValue as? CKRecordValue
                }
            }
        }
    }


    func useBest(record iRecord: CKRecord) {
        let      myDate = record?.modificationDate
        if  let newDate = iRecord.modificationDate,
            (myDate    == nil || myDate!.timeIntervalSince(newDate) < 0.000001) {
            record      = iRecord
        }
    }


    func copy(into copy: ZRecord) {
        copy.maybeNeedSave() // so KVO won't set needsMerge
        updateRecordProperties()
        record.copy(to: copy.record, properties: cloudProperties())
        copy.updateInstanceProperties()
    }


    func mergeIntoAndTake(_ iRecord: CKRecord) {
        updateRecordProperties()

        if  record != nil && record.copy(to: iRecord, properties: cloudProperties()) {
            record  = iRecord

            maybeNeedSave()
        }
    }


    // MARK:- states
    // MARK:-


    func    hasState(_ state: ZRecordState) -> Bool { return recordsManager?.hasZRecord(self, forAnyOf:[state]) ?? false }
    func    addState(_ state: ZRecordState)         {        recordsManager?.addZRecord(self,     for: [state]) }
    func removeState(_ state: ZRecordState)         {        recordsManager?.clearRecordName(recordName, for:[state]) }
    func clearAllStates()                           {        recordsManager?.clearRecordName(recordName, for: recordsManager?.allStates ?? []) }


    func needRoot()       { addState(.needsRoot) }
    func needFetch()      { addState(.needsFetch) }
    func needCount()      { addState(.needsCount) }
    func needColor()      { addState(.needsColor) }
    func needTraits()     { addState(.needsTraits) }
    func needParent()     { addState(.needsParent) }
    func needWritable()   { addState(.needsWritable) }
    func requireFetch()   { addState(.requiresFetch) }
    func markNotFetched() { addState(.notFetched) }
    func allowSave()      { removeState(.requiresFetch)}


    func needSave() {
        allowSave()
        maybeNeedSave()
    }


    func needProgeny() {
        if  !gFullFetch || hasMissingProgeny() {
            addState(.needsProgeny)
            removeState(.needsChildren)
        }
    }


    func needDestroy() {
        if  canSave {
            addState   (.needsDestroy)
            removeState(.needsSave)
            removeState(.needsMerge)
        }
    }


    func needChildren() {
        if   !isBookmark && // all bookmarks are childless, by design
            (!gFullFetch || (showChildren && hasMissingChildren() && !needsProgeny)) {
            addState(.needsChildren)
        }
    }


    func maybeMarkNotFetched() {
        if  record?.creationDate == nil {
            markNotFetched()
        }
    }


    func maybeNeedSave() {
        if !needsDestroy, (isFromCloud || (!needsFetch && canSave)) {
            removeState(.needsMerge)
            addState   (.needsSave)
        }
    }


    func maybeNeedMerge() {
        if  isFromCloud, canSave, !needsSave, !needsMerge, !needsDestroy {
            addState(.needsMerge)
        }
    }


    func maybeFromCloud() {
        if  let r = record {
            r.maybeFromCloud(databaseID)
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


    // MARK:- files
    // MARK:-


    func type(from keyPath: String) -> ZStorageType? {
        let typeFromSuffixFollowing = { (iPrefix: String) -> (ZStorageType?) in
            let           parts = keyPath.components(separatedBy: iPrefix)

            if  parts.count > 1 {
                let      suffix = parts[1].lowercased()

                if  let    type = ZStorageType(rawValue: suffix) {
                    return type
                }
            }

            return nil
        }

        if            [kpParent, kpOwner]         .contains(keyPath) { return nil       // must be first ...
        } else if let type = ZStorageType(rawValue: keyPath)         { return type      // ZStorageType now ignores two (zoneOwner and zoneParent)
        } else if let type = typeFromSuffixFollowing(kpZonePrefix)   { return type      // this deals with those two
        } else if let type = typeFromSuffixFollowing(kpRecordPrefix) { return type
        } else                                                       { return nil
        }
    }


    func extract(valueOf iType: ZStorageType, at iKeyPath: String) -> NSObject? {
        var value  = record?[iKeyPath] as? NSObject     // all properties are extracted from record, using iKeyPath as key

        if  value == nil, iKeyPath == kpRecordName {    // except for the record name
            value  = recordName as NSObject?
        }

        return value
    }


    func prepare(_ iObject: NSObject, of iType: ZStorageType) -> NSObject? {
        var object = iObject

        switch iType {
        case .owner:
            if  let  ref = object as? CKReference {
                let name = ref.recordID.recordName as NSObject
                object   = name
            }
        case .link, .parentLink:
            if  let link = object as? String, !isValid(link) {
                return nil
            }
        default: break
        }

        return object
    }


    func storageDictionary(for iDatabaseID: ZDatabaseID) -> ZStorageDict? {
        let  keyPaths = cloudProperties() + [kpRecordName]
        var      dict = ZStorageDict()

        for keyPath in keyPaths {
            if  let       type = type(from: keyPath),
                let    extract = extract(valueOf: type, at: keyPath) ,
                let   prepared = prepare(extract, of: type) {
                    dict[type] = prepared
                }
            }

            return dict
        }


    func setStorageDictionary(_ dict: ZStorageDict, of iRecordType: String, into iDatabaseID: ZDatabaseID) {
        databaseID  = iDatabaseID
        if let name = dict[.recordName] as? String {
            record  = CKRecord(recordType: iRecordType, recordID: CKRecordID(recordName: name)) // YIKES this may be wildly out of date

            for keyPath in cloudProperties() {
                if  let      type  = type(from: keyPath),
                    let    object  = dict[type],
                    var     value  = object as? CKRecordValue {
                    if       type == .owner,
                        let string = object as? String {
                        value      = CKReference(recordID: CKRecordID(recordName: string), action: .none)
                    }

                    record[keyPath] = value
                }
            }

            updateInstanceProperties()    // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }

}
