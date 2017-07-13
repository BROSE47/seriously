//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZCloudManager: ZRecordsManager {
    var cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var database: CKDatabase? { return gRemoteStoresManager.databaseForMode(storageMode) }

    
    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
            operation.qualityOfService = .background
            operation.container        = gRemoteStoresManager.container
            operation.database         = database

            return operation
        }

        return nil
    }


    func start(_ operation: CKOperation) {
        dispatchAsyncInBackground {
            operation.start()
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func create(_ onCompletion: IntegerClosure?) {
        let needCreating = pullRecordsWithMatchingStates([.needsCreate])
        let        count = needCreating.count

        onCompletion?(count)

        if  count > 0, let  operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation  .recordsToSave = needCreating
            operation.completionBlock = {
                self.create(onCompletion)
            }

            columnarReport("CREATE \(count)", stringForRecords(operation.recordsToSave))
            start(operation)
        }
    }


    func save(_ onCompletion: IntegerClosure?) {
        if  let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation.recordsToSave = pullRecordsWithMatchingStates([.needsSave])  // clears state BEFORE looking at manifest

            if let count = operation.recordsToSave?.count {
                onCompletion?(count)

                if count > 0 {
                    operation.completionBlock = {
                        // deal with saved records marked as deleted
                        for record: CKRecord in operation.recordsToSave! {
                            if let zone = self.zoneForRecordID(record.recordID), zone.isDeleted {
                                self.unregisterZone(zone)
                            }
                        }

                        self.save(onCompletion)
                    }

                    operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
                        // mark failed records as needing merge
                        if  let error:  CKError = iError as? CKError {
                            let info            = error.errorUserInfo
                            var description     = info["CKErrorDescription"] as! String

                            if  description    != "record to insert already exists" {
                                if  let  record = self.recordForCKRecord(iRecord) {
                                    record.maybeNeedMerge()
                                }

                                if  let    name = iRecord?[zoneNameKey] as? String {
                                    description = "\(description): \(name)"
                                }

                                self.columnarReport("SAVE ERROR", "\(self.storageMode) \(description)")
                            }
                        }
                    }
                    
                    columnarReport("SAVE \(count)", stringForRecords(operation.recordsToSave))
                    start(operation)
                }
            }
        } else {
            onCompletion?(0)
        }
    }


    func emptyTrash(_ onCompletion: IntegerClosure?) {
        let   predicate = NSPredicate(format: "zoneState <= %d", ZoneState.IsDeleted.rawValue)
        var toBeDeleted = [CKRecordID] ()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            // iRecord == nil means: end of response to this particular query

            if iRecord != nil {
                self.columnarReport("DELETE", String(describing: iRecord![zoneNameKey]))
                toBeDeleted.append((iRecord?.recordID)!)

            } else if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
                operation.recordIDsToDelete = toBeDeleted   // delete them
                operation.completionBlock   = {
                    onCompletion?(0)
                }

                self.start(operation)
            } else {
                onCompletion?(0)
            }
        }
    }


    func undeleteAll(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d", ZoneState.IsDeleted.rawValue) // "parent = nil")

        onCompletion?(-1)

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                onCompletion?(0)
            } else {
                let            root = gRemoteStoresManager.rootZone(for: self.storageMode)
                let         deleted = self.recordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, storageMode: self.storageMode)
                deleted  .isDeleted = false

                if  deleted.parent != nil {
                    deleted.needParent()
                } else {
                    deleted.parentZone = root

                    root?.needFetch()
                }

                deleted.maybeNeedMerge()
                deleted.updateCloudProperties()
            }
        }
    }


    // MARK:- request from cloud
    // MARK:-


    func assureRecordExists(withRecordID recordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        let done: RecordClosure = { (record: CKRecord?) in
            self.dispatchAsyncInForeground {
                onCompletion(record)
            }
        }

        if  database == nil {
            done(nil)
        } else {
            dispatchAsyncInBackground {
                self.database?.fetch(withRecordID: recordID) { (fetchedRecord: CKRecord?, fetchError: Error?) in
                    if  fetchError == nil && fetchedRecord != nil {
                        done(fetchedRecord)
                    } else {
                        let brandNew: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                        self.database?.save(brandNew) { (savedRecord: CKRecord?, saveError: Error?) in
                            if (saveError != nil) {
                                done(nil)
                            } else {
                                done(savedRecord!)
                                gFileManager.save(to: self.storageMode)
                            }
                        }
                    }
                }
            }
        }
    }


    func queryWith(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        let nilCompletion = {
            onCompletion?(nil)
        }

        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: zoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                if error != nil {
                    self.reportError(error, predicate.description)
                }

                nilCompletion()
            }

            start(operation)
        } else {
            nilCompletion()
        }
    }


    func searchPredicateFrom(_ searchString: String) -> NSPredicate {
        let    tokens = searchString.components(separatedBy: " ")
        var separator = ""
        var    suffix = ""

        for token in tokens {
            if  token    != "" {
                suffix    = "\(suffix)\(separator)SELF CONTAINS \"\(token)\""
                separator = " AND "
            }
        }

        // return NSPredicate(format: "zoneState < \(ZoneState.IsFavorite.rawValue)\(separator)\(suffix)")
        return NSPredicate(format: suffix)
    }


    func bookmarkPredicate(from iRecordIDs: [CKRecordID]) -> NSPredicate {
        let separator = " AND "
        var    suffix = ""

        for identifier in iRecordIDs {
            suffix = String(format: "%@%@SELF CONTAINS \"%@\"", suffix, separator, identifier.recordName)
        }

        return NSPredicate(format: "zoneState <= \(ZoneState.IsUpToDate.rawValue)\(suffix)")
    }


    func search(for searchString: String, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchString)
        var   records = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if iRecord != nil {
                records.append(iRecord!)
            } else {
                onCompletion?(records as NSObject)
            }
        }
    }


    func bookmarks(_ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge], pull: true)
        let     count = recordIDs.count

        onCompletion?(count)

        if  count > 0 {
            let predicate = bookmarkPredicate(from: recordIDs)

            queryWith(predicate) { iRecord in
                if iRecord == nil {
                    self.bookmarks(onCompletion) // recurse for remaining
                } else if self.recordForCKRecord(iRecord) == nil {
                    let _ = Zone(record: iRecord, storageMode: self.storageMode) // register
                }
            }
        }
    }


    func merge(_ onCompletion: IntegerClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let  operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs       = recordIDs
            operation.completionBlock = {
                self.clearRecordIDs(recordIDs, for: [.needsMerge])
                self.merge(onCompletion) // recurse for remaining
            }

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if  let    record = self.recordForRecordID(iID) {
                    if  let error = iError as? CKError {
                        let  name = record.record[zoneNameKey] as? String ?? "---"

                        self.reportError("MERGE ==> \(self.storageMode) \(error) \(name)")
                    } else {
                        record.mergeIntoAndTake(iRecord!)
                    }
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge])
            }

            self.columnarReport("MERGE", stringForRecordIDs(recordIDs, in: storageMode))
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    // MARK:- fetch
    // MARK:-


    func fetch(_ onCompletion: IntegerClosure?) {
        let needed = pullReferencesWithMatchingStates([.needsFetch])
        let  count = needed.count

        onCompletion?(count)

        if count > 0 {
            let predicate = NSPredicate(format: "zoneState < %d AND recordID IN %@", ZoneState.IsFavorite.rawValue, needed)

            columnarReport("FETCH", stringForReferences(needed, in: storageMode))

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                    self.fetch(onCompletion)
                } else {
                    if let record = self.recordForCKRecord(iRecord) {
                        record.unmarkForAllOfStates([.needsFetch])    // deferred to make sure fetch worked before clearing fetch flag

                        record.record = iRecord

                        if let zone = record as? Zone {
                            zone.updateLevel()
                        }
                    }
                }
            }
        }
    }


    func fetchFavorites(_ onCompletion: IntegerClosure?) {
        let predicate = NSPredicate(format: "zoneState >= %d AND zoneState < %d", ZoneState.IsFavorite.rawValue, ZoneState.IsDeleted.rawValue)

        onCompletion?(-1)
        gFavoritesManager.setup()

        self.queryWith(predicate) { (iRecord: CKRecord?) in
            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
                gFavoritesManager.rootZone?.respectOrder()
                onCompletion?(0)
            } else {
                let        favorite = Zone(record: iRecord, storageMode: self.storageMode)
                favorite.parentZone = gFavoritesManager.rootZone
                var    isDuplicated = false

                // avoid adding a duplicate (which was created by a bug)

                if  let                 name  = favorite.zoneName, let root = gFavoritesManager.rootZone {
                    for zone: Zone in root.children {
                        if  let         link  = favorite.zoneLink {
                            if          link == zone.zoneLink {
                                isDuplicated  = true

                                break
                            }
                        }

                        if name == zone.zoneName {
                            isDuplicated   = true

                            break
                        }
                    }
                }

                if isDuplicated {
                    favorite.isDeleted = true

                    favorite.needSave()
                } else {
                    gFavoritesManager.rootZone?.addChild(favorite)

                    if let recordID = favorite.crossLink?.record.recordID, self.zoneForRecordID(recordID) == nil {
                        self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey, onCompletion: { iRecord in
                            let zone = Zone(record: iRecord, storageMode: self.storageMode)

                            zone.needSave()
                            zone.needRoot()
                            self.columnarReport("COLOR", zone.zoneName)
                        })
                    }
                }
            }
        }
    }


    func fetchManifest(_ onCompletion: IntegerClosure?) {
        onCompletion?(-1)

        let     mine = gRemoteStoresManager.cloudManagerFor(.mine)
        let manifest = gRemoteStoresManager.manifest(for: storageMode)
        let recordID = manifest.record.recordID

        mine.assureRecordExists(withRecordID: recordID, recordType: manifestTypeKey) { (iManifestRecord: CKRecord?) in
            if iManifestRecord != nil {
                manifest.record = iManifestRecord
            }

            onCompletion?(0)
        }
    }


    func fetchToRoot(_ onCompletion: IntegerClosure?) {
        let            here = gRemoteStoresManager.manifest(for: storageMode).hereZone
        let        requests = hasRecords(for: [.needsRoot])
        let hasCompletePath = here.hasCompleteAncestorPath()

        if  rootZone != nil && hasCompletePath && !requests {
            onCompletion?(0)
        } else {
            onCompletion?(-1)

            typealias         ZoneBooleanClosure = (Zone, Bool) -> (Void)
            var                          visited = [Zone]()
            var getParentOf: ZoneBooleanClosure? = nil

            let againFetchToRoot = { (iRecurse: Bool) in
                if iRecurse {
                    self.dispatchAsyncInBackground {    // prevent pileup
                        self.fetchToRoot(onCompletion)  // grab more or make final call to closure
                    }
                }
            }

            getParentOf = { (iZone, iRecurse) in
                if  visited.contains(iZone) || iZone.isRoot || iZone.isRootOfFavorites || iZone.hasCompleteAncestorPath() {
                    againFetchToRoot(iRecurse)
                } else {
                    iZone.needParent()

                    self.fetchParents() { iResult in
                        if iResult == 0 {
                            if  let parent = iZone.parentZone {
                                visited    = visited + [iZone]

                                getParentOf?(parent, iRecurse)  // recurse for remaining
                            } else if iZone.isRoot {
                                self.rootZone = iZone           // got root

                                againFetchToRoot(iRecurse)      // so will call onCompletion
                            } else {
                                onCompletion?(0)                // prevent [operations manager] hang
                            }
                        }
                    }
                }
            }

            if !hasCompletePath {
                getParentOf?(here, true)
            } else if requests {
                let needRoot = pullRecordsWithMatchingStates([.needsRoot])
                var    count = needRoot.count

                for need in needRoot {
                    count   -= 1

                    getParentOf?(zoneForRecord(need), count == 0)
                }
            } else {
                onCompletion?(0)
            }
        }
    }


    func fetchParents(_ onCompletion: IntegerClosure?) {
        let missingParents = parentIDsWithMatchingStates([.needsParent])
        let        orphans = recordIDsWithMatchingStates([.needsParent])

        if  missingParents.count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            operation.recordIDs       = missingParents
            operation.completionBlock = {
                self.clearRecordIDs(missingParents, for: [.needsParent])
                onCompletion?(0)
            }

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                var parent = self.zoneForRecordID(iID)

                if parent != nil && iRecord != nil {
                    parent?.mergeIntoAndTake(iRecord!) // BROKEN: likely this does not do what's needed here
                } else if let error: CKError = iError as? CKError {
                    self.reportError(error)
                } else {
                    parent = self.zoneForRecord(iRecord!)

                    for orphan in orphans {
                        if let child = self.zoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == parent?.record.recordID {
                            parent?.children.append(child)
                        }
                    }
                }

                if parent != nil {
                    parent?.updateLevel()
                }
            }

            columnarReport("PARENTS of", stringForRecordIDs(orphans, in: storageMode))
            clearState(.needsParent)
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ iLogic: ZRecursionLogic? = ZRecursionLogic(.restore), _ onCompletion: IntegerClosure?) {
        let  progenyNeeded = pullReferencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = pullReferencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let          logic = iLogic ?? ZRecursionLogic(.restore)
        var          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var didDone = false
            var parentsNeedingResort = [Zone] ()
            let            predicate = NSPredicate(format: "zoneState < %d AND parent IN %@", ZoneState.IsFavorite.rawValue, childrenNeeded)
            let done = {
                if !didDone {
                    didDone = true

                    for parent in parentsNeedingResort {
                        parent.respectOrder()
                    }

                    self.fetchChildren(logic, onCompletion) // recurse to grab children of received children
                }
            }

            columnarReport("CHILDREN of", stringForReferences(childrenNeeded, in: storageMode))
            queryWith(predicate) { (iRecord: CKRecord?) in
                if iRecord != nil { // nil means: we already received full response from cloud for this particular fetch
                    let child = self.zoneForRecord(iRecord!)
                    count    -= 1

                    if !child.isDeleted && !child.isRoot {
                        logic.propagateNeeds(to: child, progenyNeeded)

                        if let parent  = child.parentZone {
                            if parent != child && !parent.children.contains(child) {
                                parent.addChild(child)

                                if !parentsNeedingResort.contains(parent) {
                                    parentsNeedingResort.append(parent)
                                }
                            }
                        } else {
                            self.columnarReport("CHILD", child.unwrappedName)
                        }
                    }


                    if count <= 0 {
                        self.dispatchAsyncInForegroundAfter(1.0) {
                            done()
                        }
                    }
                } else {
                    done()
                }
            }
        }
    }


    func fetchCloudZones(_ onCompletion: IntegerClosure?) {
        onCompletion?(-1)

        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                gRemoteStoresManager.resetBadgeCounter()

                onCompletion?(0)
            }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ onCompletion: IntegerClosure?) {
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        let rootCompletion = {
            self.establishRoot { iValue in
                if iValue == 0 {
                    self.rootZone?.needProgeny()
                }

                onCompletion?(iValue)
            }
        }

        if manifest.here == nil {
            rootCompletion()
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[zoneNameKey] == nil {
                    rootCompletion()
                } else {
                    let          here = self.zoneForRecord(iHereRecord!)
                    here      .record = iHereRecord
                    manifest.hereZone = here

                    here.needProgeny()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ onCompletion: IntegerClosure?) {
        let recordID = CKRecordID(recordName: rootNameKey)

        onCompletion?(-1)

        assureRecordExists(withRecordID: recordID, recordType: zoneTypeKey) { (iRecord: CKRecord?) in
            if iRecord != nil {
                let      root = self.zoneForRecord(iRecord!)    // get / create root
                self.rootZone = root
                root   .level = 0
            }

            onCompletion?(0)
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func unsubscribe(_ onCompletion: IntegerClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            onCompletion?(-1)
            database!.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if iError != nil {
                    onCompletion?(0)
                    self.reportError(iError)
                } else {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        onCompletion?(0)
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.database!.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iUnsubscribeError: Error?) in
                                if iUnsubscribeError != nil {
                                    self.reportError(iUnsubscribeError)
                                }

                                count -= 1

                                if count == 0 {
                                    onCompletion?(0)
                                }
                            })
                        }
                    }
                }
            }
        }
    }


    func subscribe(_ onCompletion: IntegerClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            let classNames = [zoneTypeKey, manifestTypeKey]
            var      count = classNames.count

            onCompletion?(-1)
            for className: String in classNames {
                let    predicate:          NSPredicate = NSPredicate(value: true)
                let subscription:       CKSubscription = CKQuerySubscription(recordType: className, predicate: predicate, options: [.firesOnRecordUpdate])
                let  information:   CKNotificationInfo = CKNotificationInfo()
                information.alertLocalizationKey       = "new Focus data has arrived";
                information.shouldBadge                = true
                information.shouldSendContentAvailable = true
                subscription.notificationInfo          = information

                database!.save(subscription, completionHandler: { (iSubscription: CKSubscription?, iSubscribeError: Error?) in
                    if iSubscribeError != nil {
                        self.signalFor(iSubscribeError as NSObject?, regarding: .error)
                        self.reportError(iSubscribeError)
                    }

                    count -= 1
                    
                    if count == 0 {
                        onCompletion?(0)
                    }
                })
            }
        }
    }


    func setIntoObject(_ object: ZRecord, value: NSObject?, for property: String) {
        if  let   record = object.record, database != nil {
            let oldValue = record[property] as? NSObject

            if oldValue         != value {
                record[property] = value as? CKRecordValue

                object.maybeNeedMerge()
            }
        }
    }


    func getFromObject(_ object: ZRecord, valueForPropertyName: String) {
        if  database != nil && object.record != nil {
            let      predicate = NSPredicate(value: true)
            let  type: String  = NSStringFromClass(type(of: object)) as String
            let query: CKQuery = CKQuery(recordType: type, predicate: predicate)

            database?.perform(query, inZoneWith: nil) { (iResults: [CKRecord]?, performanceError: Error?) in
                if performanceError != nil {
                    self.signalFor(performanceError as NSObject?, regarding: .error)
                } else {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }
}

