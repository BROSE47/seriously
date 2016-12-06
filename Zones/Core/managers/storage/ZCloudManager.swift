//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: ZRecordsManager {
    var cloudZonesByID: [CKRecordZoneID : CKRecordZone] = [:]
    var      container:                    CKContainer!

    
    var currentDB: CKDatabase? {
        get {
            switch (travelManager.storageMode) {
            case .everyone: return container.publicCloudDatabase
            case .group:    return container.sharedCloudDatabase
            case .mine:     return container.privateCloudDatabase
            default:        return nil
            }
        }
    }


    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if currentDB == nil {
            return nil
        }

        operation.qualityOfService = .background
        operation.container        = container
        operation.database         = currentDB

        return operation
    }


    func clear() {
        zones.removeAll()
    }


    // MARK:- operations
    // MARK:-


    func fetchCloudZones(_ onCompletion: (() -> Swift.Void)?) {
        container = CKContainer(identifier: cloudID)

        bookmarksManager.setup()
        travelManager   .setup()

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) -> Swift.Void in
                self.cloudZonesByID                   = recordZonesByZoneID!

                self.resetBadgeCounter()

                onCompletion?()
            }

            operation.start()

            return
        }

        onCompletion?()
    }


    func establishHere(_ block: (() -> Swift.Void)?) {
        var recordID: CKRecordID = CKRecordID(recordName: manifestNameKey)
        let callBlock = true

//        assureRecordExists(withRecordID: recordID, recordType: manifestTypeKey, onCompletion: { (record: CKRecord?) -> (Void) in
//            if record != nil {
//                travelManager.manifest.record = record
//            }
//
//            if travelManager.manifest.here != nil {
//                recordID  = (travelManager.manifest.here?.recordID)!
//                callBlock = false
//
//                self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey, onCompletion: { (record: CKRecord?) -> (Void) in
//                    if record != nil {
//                        travelManager.hereZone?.record = record
//                        travelManager.hereZone?.needChildren()
//                        travelManager.manifest.needSave()
//                    }
//
//                    block?()
//                })
//            }

            recordID = CKRecordID(recordName: rootNameKey)

            self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord?) -> (Void) in
                if iRecord != nil {
                    travelManager.rootZone?.record = iRecord
                    travelManager.rootZone?.needChildren()

                    if iRecord != travelManager.rootZone?.record {
                        self.reportError(travelManager.rootZone?.zoneName)
                    }

                    if travelManager.manifest.here == nil {
                        travelManager.hereZone = travelManager.rootZone
                        travelManager.manifest.needSave()
                    }
                }

                if callBlock {
                    block?()
                }
            })
//        })
    }


    func merge(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching([.needsMerge])

            if (operation.recordIDs?.count)! > 0 {

                reportError("merging \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    let zone = self.zoneForRecordID(iID)

                    if iRecord != nil {
                        zone?.mergeIntoAndTake(iRecord!)
                    } else if let error: CKError = iError as? CKError {
                        self.reportError(error)

                        zone?.needSave()
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func fetch(_ onCompletion: (() -> Swift.Void)?) {
        if let        operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs = recordIDsMatching([.needsFetch])

            if (operation.recordIDs?.count)! > 0 {

                reportError("fetching \((operation.recordIDs?.count)!)")

                operation.completionBlock          = onCompletion
                operation.perRecordCompletionBlock = { (iRecord, iID, iError) in
                    if let error: CKError = iError as? CKError {
                        self.reportError(error)
                    } else if let zone: Zone = self.zoneForRecordID(iID) {
                        self.removeRecord(zone, forState: .needsFetch)

                        zone.record = iRecord
                    }
                }

                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    func royalFlush(_ onCompletion: (() -> Swift.Void)?) {
        for zone in zones.values {
            if !hasRecord(zone, forState: .needsFetch) && !hasRecord(zone, forState: .needsSave) && !hasRecord(zone, forState: .needsCreate) {
                removeRecord(zone, forState: .needsMerge)
                zone.normalizeOrdering()
                zone.updateCloudProperties()
            }
        }

        operationsManager.sync(onCompletion)
    }


    func create(_ onCompletion: (() -> Swift.Void)?) {
        if let operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave   = recordsMatching([.needsCreate])
            operation.completionBlock = onCompletion

            clearState(.needsCreate)

            if (operation.recordsToSave?.count)! > 0 {

                reportError("creating \((operation.recordsToSave?.count)!)")

                operation.start()
                
                return
            }
        }
        
        onCompletion?()
    }


    func flush(_ onCompletion: (() -> Swift.Void)?) {
        if let operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave     =   recordsMatching([.needsSave])
            operation.recordIDsToDelete = recordIDsMatching([.needsDelete])

            clearStates([.needsSave, .needsDelete])

            if (operation.recordsToSave?.count)! > 0 || (operation.recordIDsToDelete?.count)! > 0 {

                reportError("saving \((operation.recordsToSave?.count)!) deleting \((operation.recordIDsToDelete?.count)!)")

                operation.completionBlock          = { () in
                    for identifier: CKRecordID in operation.recordIDsToDelete! {
                        let zone = self.zones[identifier]

                        zone?.parentZone?.removeChild(zone)
                        self.zones.removeValue(forKey: identifier)
                    }

                    controllersManager.signal(nil, regarding: .data)
                    onCompletion?()
                }
                operation.perRecordCompletionBlock = { (iRecord, iError) -> Swift.Void in
                    if  let error:         CKError = iError as? CKError {
                        let info                   = error.errorUserInfo
                        var description:    String = info["ServerErrorDescription"] as! String

                        if  description           != "record to insert already exists" {
                            if let zone            = self.zoneForRecordID((iRecord?.recordID)!) {
                                zone.needFetch()
                            }

                            if let name            = iRecord?["zoneName"] as! String? {
                                description        = "\(description): \(name)"
                            }

                            self.reportError(description)
                        }
                    }
                }
                
                operation.start()
                
                return
            }
        }

        onCompletion?()
    }


    @discardableResult func fetchChildren(_ onCompletion: (() -> Swift.Void)?) -> Bool {
        let childrenNeeded: [CKReference] = referencesMatching([.needsChildren])

        clearState(.needsChildren)

        if childrenNeeded.count > 0, let operation = configure(CKQueryOperation()) as? CKQueryOperation {

            reportError("fetching children of \(childrenNeeded.count)")

            var parentsNeedingResort: [Zone] = []
            let                    predicate = NSPredicate(format: "parent IN %@", childrenNeeded)
            operation.query                  = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation.desiredKeys            = Zone.cloudProperties()
            operation.recordFetchedBlock     = { iRecord -> Swift.Void in
                var zone = self.zoneForRecordID(iRecord.recordID)

                if zone == nil {
                    zone = Zone(record: iRecord, storageMode: travelManager.storageMode)
                }

                zone?.updateZoneProperties()
                zone?.needChildren()

                if let parent = zone?.parentZone {
                    if parent != zone {
                        if !parent.children.contains(zone!) {
                            parent.children.append(zone!)
                        }

                        if !parentsNeedingResort.contains(parent) {
                            parentsNeedingResort.append(parent)
                        }

                        return
                    }

                    return
                }

                self.reportError(zone?.zoneName)
            }

            operation.queryCompletionBlock = { (cursor, error) -> Swift.Void in
                if error != nil {
                    self.reportError(error)
                }

                for parent in parentsNeedingResort {
                    parent.respectOrder()
                }

                controllersManager.signal(nil, regarding: .data)

                self.fetchChildren(onCompletion)
            }

            operation.start()

            return false // false means more to do
        }

        onCompletion?()

        return true
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey, onCompletion: { (iRecord: CKRecord) -> (Void) in
            var zone = self.zoneForRecordID(iRecord.recordID)

            if  zone != nil {
                zone?.record = iRecord
            } else {
                zone = Zone(record: iRecord, storageMode: travelManager.storageMode)
            }

            zone?.needChildren()

            self.dispatchAsyncInForeground {
                controllersManager.signal(zone?.parentZone, regarding: .data)

                operationsManager.getChildren {
                    controllersManager.signal(zone?.parentZone, regarding: .data)
                }
            }
        } as! RecordClosure)
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        if currentDB == nil {
            onCompletion(nil)
        } else {
            currentDB?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    onCompletion(fetched!)
                } else {
                    let created: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                    self.currentDB?.save(created, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                        if (saveError != nil) {
                            onCompletion(nil)
                        } else {
                            onCompletion(saved!)
                            zfileManager.save()
                        }
                    })
                }
            }
        }
    }


    func className(of:AnyObject) -> String {
        return NSStringFromClass(type(of: of)) as String
    }


    // MARK:- remote persistence
    // MARK:-


    func resetBadgeCounter() {
        container.accountStatus { (iStatus, iError) in
            if iStatus == .available {
                let badgeResetOperation = CKModifyBadgeOperation(badgeValue: 0)

                badgeResetOperation.modifyBadgeCompletionBlock = { (error) -> Void in
                    if error == nil {
                        zapplication.clearBadge()
                    }
                }

                self.container.add(badgeResetOperation)
            }
        }
    }


    func unsubscribe(_ block: (() -> Swift.Void)?) {
        if currentDB == nil {
            block?()
        } else {
            currentDB?.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    block?()
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        block?()
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.currentDB?.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                                if iDeleteError != nil {
                                    self.reportError(iDeleteError)
                                }

                                count -= 1

                                if count == 0 {
                                    block?()
                                }
                            })
                        }
                    }
                }
            }
        }
    }


    func subscribe(_ block: (() -> Swift.Void)?) {
        if currentDB == nil {
            block?()
        } else {
            let classNames = [zoneTypeKey, "ZManifest"] //, "ZTrait", "ZAction"]
            var      count = classNames.count

            for className: String in classNames {
                let    predicate:          NSPredicate = NSPredicate(value: true)
                let subscription:       CKSubscription = CKSubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
                let  information:   CKNotificationInfo = CKNotificationInfo()
                information.alertLocalizationKey       = "somthing has changed, hah!";
                information.shouldBadge                = true
                information.shouldSendContentAvailable = true
                subscription.notificationInfo          = information

                currentDB?.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSaveError: Error?) in
                    if iSaveError != nil {
                        controllersManager.signal(iSaveError as NSObject?, regarding: .error)

                        self.reportError(iSaveError)
                    }

                    count -= 1
                    
                    if count == 0 {
                        block?()
                    }
                })
            }
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject?, forPropertyName: String) {
        if currentDB != nil {
            if let    record = object.record {
                let oldValue = record[forPropertyName] as? NSObject

                if oldValue != value {
                    record[forPropertyName] = value as! CKRecordValue?

                    if !cloudManager   .hasRecord(object, forState: .needsCreate) {
                        cloudManager.removeRecord(object, forState: .needsMerge)
                    }
                }
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if currentDB != nil && object.record != nil && operationsManager.isReady {
            let      predicate = NSPredicate(format: "")
            let  type: String  = className(of: object);
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            currentDB?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    controllersManager.signal(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    controllersManager.signal(nil, regarding: .data)
                }
            }
        }
    }
}

