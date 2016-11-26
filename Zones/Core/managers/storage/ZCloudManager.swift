//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: NSObject {
    var        records:          [CKRecordID : ZRecord] = [:]
    var cloudZonesByID: [CKRecordZoneID : CKRecordZone] = [:]
    var      container:                    CKContainer!
    var      currentDB:                     CKDatabase? { get { return databaseForMode(travelManager.storageMode) }     }


    func databaseForMode(_ mode: ZStorageMode) -> CKDatabase? {
        switch (mode) {
        case .everyone: return container.publicCloudDatabase
        case .group:    return container.sharedCloudDatabase
        case .mine:     return container.privateCloudDatabase
        default:        return nil
        }
    }


    func setupOperation(_ operation: CKDatabaseOperation) -> CKDatabaseOperation {
        operation.container               = container
        operation.database                = currentDB
        operation.qualityOfService        = .background

        return operation
    }


    func cloudSetup(_ block: (() -> Swift.Void)?) {
        container                                 = CKContainer(identifier: cloudID)
        let                             operation = setupOperation(CKFetchRecordZonesOperation()) as! CKFetchRecordZonesOperation
        operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) -> Swift.Void in
            self.cloudZonesByID = recordZonesByZoneID!

            self.resetBadgeCounter()

            block?()
        }

        travelManager.setup()
        operation.start()
    }


    // MARK:- records
    // MARK:-


    func fetchOnCompletion(_ block: (() -> Swift.Void)?) {
        let                     operation = setupOperation(CKFetchRecordsOperation()) as! CKFetchRecordsOperation
        operation.completionBlock         = block
        var recordsToFetch:  [CKRecordID] = []

        for record: ZRecord in records.values {
            switch record.recordState {
            case .needsFetch: recordsToFetch.append(record.record.recordID); break
            default:                                                         break
            }
        }

        if recordsToFetch.count > 0 {
            operation.recordIDs = recordsToFetch

            operation.start()
        } else {
            block?()
        }
    }


    func flushOnCompletion(_ block: (() -> Swift.Void)?) {
        let                     operation = setupOperation(CKModifyRecordsOperation()) as! CKModifyRecordsOperation
        var recordsToDelete:  [CKRecordID] = []
        var recordsToSave:      [CKRecord] = []

        for record: ZRecord in records.values {
            switch record.recordState {
            case .needsSave:   recordsToSave  .append(record.record);          break
            case .needsDelete: recordsToDelete.append(record.record.recordID); break
            default:                                                           break
            }
        }

        operation.recordsToSave            = recordsToSave
        operation.recordIDsToDelete        = recordsToDelete
        operation.completionBlock          = block // { () -> Swift.Void in self.fetchOnCompletion(block) }
        operation.perRecordCompletionBlock = { (iRecord, iError) -> Swift.Void in
            if  let error:         CKError = iError as? CKError {
                let info                   = error.errorUserInfo
                var description:    String = info["ServerErrorDescription"] as! String

                if  description           != "record to insert already exists" {
                    if let zone            = self.objectForRecordID((iRecord?.recordID)!) {
                        zone.recordState   = .needsFetch
                    }

                    if let name            = iRecord?["zoneName"] as! String? {
                        description        = "\(description): \(name)"
                    }

                    self.toConsole(description)
                }
            }
        }

        operation.start()
    }


    func registerObject(_ object: ZRecord) {
        if object.record != nil {
            records[object.record.recordID] = object
        }
    }


    func objectForRecordID(_ recordID: CKRecordID) -> ZRecord? {
        return records[recordID]
    }


    func fetchReferencesTo(_ parent: Zone) {
        if let parentRecord = parent.record {
            let reference: CKReference = CKReference(recordID: parentRecord.recordID, action: .none)
            let predicate: NSPredicate = NSPredicate(format: "parent == %@", reference)
            let     query:     CKQuery = CKQuery(recordType: zoneTypeKey, predicate: predicate)

            currentDB?.perform(query, inZoneWith: nil) { (records, error) in
                if error != nil {
                    self.toConsole(error)
                }

                if records != nil && (records?.count)! > 0 {
                    for record: CKRecord in records! {
                        var zone: Zone? = self.objectForRecordID(record.recordID) as! Zone?

                        if zone == nil {
                            zone = Zone(record: record, storageMode: travelManager.storageMode)

                            self.registerObject(zone!)
                            parent.children.append(zone!)
                            self.fetchReferencesTo(zone!)
                        }

                        zone?.parentZone = parent
                    }
                    
                    controllersManager.signal(nil, regarding: .data)
                }
            }
        }
    }


    func setupRoot(_ block: (() -> Swift.Void)?) {
        let recordID: CKRecordID = CKRecordID(recordName: rootNameKey)

        assureRecordExists(withRecordID: recordID, onCompletion: { (record: CKRecord?) -> (Void) in
            if record != nil {
                travelManager.rootZone.record = record

                self.fetchReferencesTo(travelManager.rootZone)
            }

            block?()
        })
    }


    func receivedUpdateFor(_ recordID: CKRecordID) {
        resetBadgeCounter()
        assureRecordExists(withRecordID: recordID, onCompletion: { (iRecord: CKRecord) -> (Void) in
            self.dispatchAsyncInForeground {
                var zone: Zone? = self.objectForRecordID(iRecord.recordID) as! Zone?

                if  zone != nil {
                    zone?.record = iRecord
                } else {
                    zone = Zone(record: iRecord, storageMode: travelManager.storageMode)

                    self.registerObject(zone!)
                }

                self.fetchReferencesTo(zone!)
                controllersManager.signal(zone?.parentZone, regarding: .data)
            }
        } as! RecordClosure)
    }


    func assureRecordExists(withRecordID recordID: CKRecordID, onCompletion: @escaping RecordClosure) {
        if currentDB == nil {
            onCompletion(nil)
        } else {
            currentDB?.fetch(withRecordID: recordID) { (fetched: CKRecord?, fetchError: Error?) in
                if (fetchError == nil) {
                    onCompletion(fetched!)
                } else {
                    let created: CKRecord = CKRecord(recordType: zoneTypeKey, recordID: recordID)

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
                    self.toConsole(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        block?()
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.currentDB?.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iDeleteError: Error?) in
                                if iDeleteError != nil {
                                    self.toConsole(iDeleteError)
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
            let classNames = [zoneTypeKey] //, "ZTrait", "ZAction"]
            var count = classNames.count


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

                        self.toConsole(iSaveError)
                    }

                    count -= 1
                    
                    if count == 0 {
                        block?()
                    }
                })
            }
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject, forPropertyName: String) {
        if currentDB != nil {
            var                  hasChange = false
            var identifier:    CKRecordID?
            let   newValue: CKRecordValue! = (value as! CKRecordValue)
            let     record:      CKRecord? = object.record

            if record != nil {
                let oldValue: CKRecordValue! = record![forPropertyName]
                identifier                   = record?.recordID

                if oldValue != nil && newValue != nil {
                    hasChange                = (oldValue as! NSObject != newValue as! NSObject)
                } else {
                    hasChange                = oldValue != nil || newValue != nil
                }
            }

            if hasChange {
                object.recordState = .needsSave

                if (identifier != nil) {
                    currentDB?.fetch(withRecordID: identifier!) { (fetched: CKRecord?, fetchError: Error?) in
                        if fetchError != nil {
                            record?[forPropertyName]  = newValue

                            object.updateProperties()
                            controllersManager.signal(nil, regarding: .data)
                            object.saveToCloud()
                        } else {
                            fetched![forPropertyName] = newValue

                            self.currentDB?.save(fetched!, completionHandler: { (saved: CKRecord?, saveError: Error?) in
                                if saveError != nil {
                                    controllersManager.signal(saveError as NSObject?, regarding: .error)
                                } else {
                                    object.record      = saved!
                                    object.recordState = .ready

                                    controllersManager.signal(nil, regarding: .data)
                                    zfileManager.save()
                                }
                            })
                        }
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

