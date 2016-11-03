//
//  ZRecord.swift
//  Zones
//
//  Created by Jonathan Sand on 9/19/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZRecord: NSObject {
    

    var recordState: RecordState = .needsFetch
    var  kvoContext: UInt8       = 1
    var    database: CKDatabase!
    var     _record: CKRecord?


    var record: CKRecord! {
        get {
            return _record
        }

        set {
            if _record != newValue {
                _record = newValue

                if _record != nil {
                    cloudManager.registerObject(self)
                }

                updateProperties()
            }
        }
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


    init(record: CKRecord?, database: CKDatabase) {
        super.init()

        self.database = database
        self.record   = record

        self.setupKVO();
    }


    // MARK:- overrides
    // MARK:-


    func saveToCloud() {}
    func fetchChildren() {}
    func updateProperties() {}
    func cloudProperties() -> [String] { return [] }


    func setStorageDictionary(_ dict: ZStorageDict) {
        var type: String? = nil
        var name: String? = nil

        for (key, value) in dict {
            switch key {
            case recordTypeKey: type = value as? String; break
            case recordNameKey: name = value as? String; break
            default:                                    break
            }
        }

        if type != nil && name != nil {
            record = CKRecord(recordType: type!, recordID: CKRecordID(recordName: name!))

            // any subsequent changes into any of this object's cloudProperties will fetch / save this record from / to iCloud
        }
    }


    func storageDictionary() -> ZStorageDict? {
        return [recordNameKey : record.recordID.recordName as NSObject,
                recordTypeKey : record.recordType          as NSObject]
    }


    // MARK:- accessors and KVO
    // MARK:-


    func setValue(_ value: NSObject, forPropertyName: String) {
        cloudManager.setIntoObject(self, value: value, forPropertyName: forPropertyName)
    }


    func get(propertyName: String) {
        cloudManager.getFromObject(self, valueForPropertyName: propertyName)
    }


    func setupKVO() {
        for keyPath: String in cloudProperties() {
            self.addObserver(self, forKeyPath: keyPath, options: [.new, .old], context: &kvoContext)
        }
    }


    override func observeValue(forKeyPath keyPath: String?, of iObject: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            let observer = iObject as! NSObject

            if let value: NSObject = observer.value(forKey: keyPath!) as! NSObject? {
                self.setValue(value, forPropertyName: keyPath!)
            }
        }
    }
}