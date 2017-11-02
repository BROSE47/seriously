//
//  ZCloudManager.swift
//  Zones
//
//  Created by Jonathan Sand on 9/18/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gContainer = CKContainer(identifier: gCloudID)


class ZCloudManager: ZRecordsManager {
    var cloudZonesByID = [CKRecordZoneID : CKRecordZone] ()
    var database: CKDatabase? { return gRemoteStoresManager.databaseForMode(storageMode) }
    var currentOperation: CKOperation? = nil
    var currentPredicate: NSPredicate? = nil
    var mostRecentError: Error? = nil


    
    func configure(_ operation: CKDatabaseOperation) -> CKDatabaseOperation? {
        if  database != nil {
            operation.timeoutIntervalForResource = gRemoteTimeout
            operation .timeoutIntervalForRequest = gRemoteTimeout
            operation          .qualityOfService = .background
            operation                 .container = gContainer
            operation                  .database = database

            return operation
        }

        return nil
    }


    func start(_ operation: CKOperation) {
        currentOperation = operation

        BACKGROUND {     // not stall foreground processor
            operation.start()
        }
    }


    // MARK:- push to cloud
    // MARK:-


    func create(_ onCompletion: IntClosure?) {
        let needCreating = pullRecordsWithMatchingStates([.needsCreate])
        let        count = needCreating.count

        if  count > 0, let  operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation  .recordsToSave = needCreating
            operation.completionBlock = {
                self.create(onCompletion) // process remaining
            }

            columnarReport("CREATE \(count)", stringForCKRecords(needCreating))
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func save(_ onCompletion: IntClosure?) {
        let   saves = pullRecordsWithMatchingStates([.needsSave])  // clears state BEFORE looking at manifest
        let deletes = recordIDsWithMatchingStates([.needsDestroy], pull: true)
        let   count = saves.count + deletes.count

        if  count > 0, let           operation = configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
            operation       .recordIDsToDelete = deletes
            operation           .recordsToSave = saves
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iError: Error?) in
//                self.detectError(iError) {
//                    // mark failed records as needing merge
//                    if  let error:  CKError = iError as? CKError {
//                        let info            = error.errorUserInfo
//                        var description     = info["CKErrorDescription"] as! String
//
//                        if  description    != "record to insert already exists" {
//                            if  let  record = self.recordForCKRecord(iRecord) {
//                                record.maybeNeedMerge()
//                            }
//
//                            if  let    name = iRecord?[gZoneNameKey] as? String {
//                                description = "\(description): \(name)"
//                            }
//
//                            self.columnarReport("SAVE ERROR", "\(self.storageMode) \(description)")
//                        }
//                    }
//                }
            }

            operation.completionBlock   = {
                // deal with saved records marked as deleted

                self.FOREGROUND {
                    for recordID: CKRecordID in deletes {
                        if  let zone = self.zoneForRecordID(recordID) {
                            self.unregisterZone(zone)
                        }
                    }

                    for record: CKRecord in saves {
                        if  let zone = self.zoneForRecordID(record.recordID), zone.isDeleted { // only unregister deleted zones
                            self.unregisterZone(zone)
                        }
                    }

                    self.save(onCompletion)         // process remaining
                }
            }

            if   saves.count > 0 { columnarReport("SAVE \(     saves.count)", stringForCKRecords(saves)) }
            if deletes.count > 0 { columnarReport("DESTROY \(deletes.count)", stringForRecordIDs(deletes, in: storageMode)) }
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func emptyTrash(_ onCompletion: IntClosure?) {
//        let   predicate = NSPredicate(format: "zoneIsDeleted = 1")
//        var toBeDeleted = [CKRecordID] ()
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            // iRecord == nil means: end of response to this particular query
//
//            if iRecord != nil {
//                self.columnarReport("DELETE", String(describing: iRecord![gZoneNameKey]))
//                toBeDeleted.append((iRecord?.recordID)!)
//
//            } else if (toBeDeleted.count) > 0, let operation = self.configure(CKModifyRecordsOperation()) as? CKModifyRecordsOperation {
//                operation.recordIDsToDelete = toBeDeleted   // delete them
//                operation.completionBlock   = {
//                    onCompletion?(0)
//                }
//
//                self.start(operation)
//            } else {
//                onCompletion?(0)
//            }
//        }
    }


    func undeleteAll(_ onCompletion: IntClosure?) {
//        let predicate = NSPredicate(format: "zoneIsDeleted = 1")
//
//        onCompletion?(-1)
//
//        self.queryWith(predicate) { (iRecord: CKRecord?) in
//            if iRecord == nil { // nil means: we already received full response from cloud for this particular fetch
//                onCompletion?(0)
//            } else {
//                let            root = gRemoteStoresManager.rootZone(for: self.storageMode)
//                let         deleted = self.recordForCKRecord(iRecord) as? Zone ?? Zone(record: iRecord, storageMode: self.storageMode)
//
//                if  deleted.parent != nil {
//                    deleted.needParent()
//                } else {
//                    deleted.parentZone = root
//
//                    root?.needFetch()
//                }
//
//                deleted.maybeNeedMerge()
//                deleted.updateCloudProperties()
//            }
//        }
    }


    // MARK:- request from cloud
    // MARK:-


    func assureRecordExists(withRecordID recordID: CKRecordID, recordType: String, onCompletion: @escaping RecordClosure) {
        let done: RecordClosure = { (record: CKRecord?) in
            self.FOREGROUND(canBeDirect: true) {
                onCompletion(record)
            }
        }

        if  database == nil {
            done(nil)
        } else {
            BACKGROUND {     // not stall foreground processor
                self.database?.fetch(withRecordID: recordID) { (fetchedRecord: CKRecord?, fetchError: Error?) in
                    self.detectError(fetchError) {
                        let brandNew: CKRecord = CKRecord(recordType: recordType, recordID: recordID)

                        self.database?.save(brandNew) { (savedRecord: CKRecord?, saveError: Error?) in
                            if self.detectError(saveError, { done(nil) }) {
                                done(savedRecord!)
                                gFileManager.save(to: self.storageMode)
                            }
                        }
                    }

                    done(fetchedRecord)
                }
            }
        }
    }


    @discardableResult func detectError(_ iError: Error?, _ onError: Closure) -> Bool {
        let        hasError = iError != nil
        gCloudUnavailable   = hasError

        if hasError {
            mostRecentError = iError

            onError()
        }

        return !hasError
    }


    func queryWith(_ predicate: NSPredicate, onCompletion: RecordClosure?) {
        currentPredicate                 = predicate
        if  let                operation = configure(CKQueryOperation()) as? CKQueryOperation {
            operation             .query = CKQuery(recordType: gZoneTypeKey, predicate: predicate)
            operation       .desiredKeys = Zone.cloudProperties()
            operation      .resultsLimit = gBatchSize
            operation.recordFetchedBlock = { iRecord in
                onCompletion?(iRecord)
            }

            operation.queryCompletionBlock = { (cursor, error) in
                self.detectError(error) {
                    gAlertManager.report(error: error, predicate.description)
                }

                onCompletion?(nil) // nil means done
            }

            start(operation)
        } else {
            onCompletion?(nil)
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

        return NSPredicate(format: suffix)
    }


    func bookmarkPredicate(from iRecordIDs: [CKRecordID]) -> NSPredicate {
        var separator = ""
        var    suffix = ""

        for recordID in iRecordIDs {
            suffix    = String(format: "%@%@SELF CONTAINS \"%@\"", suffix, separator, recordID.recordName)
            separator = " AND "
        }

        return NSPredicate(format: suffix)
    }


    func search(for searchString: String, onCompletion: ObjectClosure?) {
        let predicate = searchPredicateFrom(searchString)
        var retrieved = [CKRecord] ()

        queryWith(predicate) { iRecord in
            if let ckRecord = iRecord {
                if !retrieved.contains(ckRecord) {
                    retrieved.append(ckRecord)
                }
            } else {
                onCompletion?(retrieved as NSObject)
            }
        }
    }


    func merge(_ onCompletion: IntClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsMerge])
        let     count = recordIDs.count

        if  count > 0, let           operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var                    recordsByID = [CKRecord : CKRecordID?] ()
            operation               .recordIDs = recordIDs
            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if  self.detectError(iError, { gAlertManager.report(error: "MERGE ==> \(self.storageMode) \(iError!)") } ) {
                    if let record = iRecord {
                        recordsByID[record] = iID
                    }
                }

                self.clearStatesForRecordID(iID, forStates:[.needsMerge])
            }

            operation.completionBlock = {
                self.FOREGROUND {
                    if recordsByID.count == 0 {
                        for ckRecordID in recordIDs {
                            self.clearStatesForRecordID(ckRecordID, forStates: [.needsMerge])
                        }
                    } else {
                        for (iRecord, iID) in recordsByID {
                            if  let record = self.recordForRecordID(iID) {
                                record.mergeIntoAndTake(iRecord)
                            }
                        }
                    }

                    self.merge(onCompletion)        // process remaining
                }
            }
            
            self.columnarReport("MERGE", stringForRecordIDs(recordIDs, in: storageMode))
            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    // MARK:- fetch
    // MARK:-


    func fetchTrash(_ onCompletion: IntClosure?) {
        if  let     trash = trashZone {
            let parentKey = "parent"
            let predicate = NSPredicate(format: "zoneName != \"\"")
            let rootNames = [gRootNameKey, gTrashNameKey, gFavoriteRootNameKey]
            var retrieved = [CKRecord] ()

            self.queryWith(predicate) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord, !retrieved.contains(ckRecord) {
                    if  let name = ckRecord[gZoneNameKey] as? String,
                        !rootNames.contains(name) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    self.FOREGROUND {
                        var    parentIDs = [CKRecordID] ()
                        var childrenRefs = [CKRecordID : CKRecord] ()

                        for ckRecord in retrieved {
                            if  let parent   = ckRecord[parentKey] as? CKReference {
                                let parentID = parent.recordID
                                if  self.recordForRecordID(parent.recordID) == nil,
                                    !rootNames.contains(parent.recordID.recordName) {
                                    childrenRefs[parentID] = ckRecord

                                    parentIDs.append(parent.recordID)
                                } // else it's already in memory (either the trash or the graph)
                            } else if let name = ckRecord[gZoneNameKey] as? String,
                                ![gRootNameKey, gTrashNameKey, gFavoriteRootNameKey].contains(name),
                                let added = trash.addCKRecord(ckRecord) {
                                added.needFlush()
                                trash.needFlush()
                            }
                        }

                        let count = parentIDs.count

                        if count == 0 {
                            onCompletion?(0)
                        } else {
                            var  destroy = [CKRecord] ()
                            var tracking = [CKRecordID] ()
                            var  closure:  RecordIDsClosure? = nil

                            closure = { iParentIDs in
                                var missing = iParentIDs

                                for recordID in tracking {
                                    if  let index = missing.index(of: recordID) {
                                        missing.remove(at: index)
                                    }
                                }

                                tracking.append(contentsOf: missing)

                                // ask cloud if referenced zone exists
                                // do the same with its parent
                                // until doesn't exist
                                // then add to trash

                                self.fetch(needed: missing) { iRetrievedParents in
                                    parentIDs = []

                                    for ckParent in iRetrievedParents {
                                        if  let index = ckParent.index(within: missing) {
                                            missing.remove(at: index)

                                            if  let grandParentRef = ckParent[parentKey] as? CKReference {
                                                parentIDs.append(grandParentRef.recordID)
                                            }
                                        } else {
                                            destroy.append(ckParent)
                                        }
                                    }

                                    if missing.count != 0 {
                                        for parent in missing {
                                            if  let    child = childrenRefs[parent] {
//                                                if  let name = child[gZoneNameKey] as? String {
//                                                    self.columnarReport(" MISSING", name)
//                                                }
                                                
                                                if let added = trash.addCKRecord(child) {
                                                    added.needFlush()
                                                    trash.needFlush()
                                                }
                                            }
                                        }
                                    }

//                                    if destroy.count != 0 {
//                                        for ckRecord in destroy {}
//                                        self.columnarReport(" DESTROY?", self.stringForCKRecords(destroy))
//                                    }

                                    let evokeClosure = parentIDs.count != 0

                                    if  evokeClosure {
                                        closure?(parentIDs)
                                    } else {
                                        onCompletion?(0)
                                    }
                                }
                            }

                            closure?(parentIDs)
                        }
                    }
                }
            }
        } else {
            onCompletion?(0)
        }
    }


    func fetch(_ onCompletion: IntClosure?) {
        let states = [ZRecordState.needsFetch]
        let needed = recordIDsWithMatchingStates(states)

        fetch(needed: needed) { iCKRecords in
            self.FOREGROUND {
                if iCKRecords.count == 0 {
                    onCompletion?(0)
                } else {
                    for ckRecord in iCKRecords {
                        var record  = self.recordForCKRecord(ckRecord)

                        if  record == nil {
                            record  = ZRecord(record: ckRecord, storageMode: self.storageMode)
                        } else {
                            record?.record = ckRecord
                        }
                    }

                    self.clearCKRecords(iCKRecords, for: states)    // deferred to make sure fetch worked before clearing fetch flag
                    self.columnarReport("FETCH", self.stringForCKRecords(iCKRecords))
                    self.fetch(onCompletion)        // process remaining
                }
            }
        }
    }


    func fetch(needed: [CKRecordID], _ onCompletion: RecordsClosure?) {
        let count = needed.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var       retrieved = [CKRecord] ()
            operation.recordIDs = needed

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if self.detectError(iError, { gAlertManager.report(error: iError) } ) {
                    if  let ckRecord = iRecord,
                        !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                }
            }

            operation.completionBlock = {
                onCompletion?(retrieved)
            }

            start(operation)
        } else {
            onCompletion?([])
        }
    }



    func fetchManifest(_ onCompletion: IntClosure?) {
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        if  manifest.alreadyExists || manifest.isMarkedForAnyOfStates([.needsCreate, .needsMerge, .needsSave]) {
            onCompletion?(0)
        } else {
            let recordID = manifest.record.recordID
            let     mine = gRemoteStoresManager.cloudManagerFor(.mineMode)

            mine.assureRecordExists(withRecordID: recordID, recordType: gManifestTypeKey) { (iManifestRecord: CKRecord?) in
                if iManifestRecord != nil {
                    manifest.record = iManifestRecord
                }

                onCompletion?(0)
            }
        }
    }


    func fetchParents(_ onCompletion: IntClosure?) {
        let states: [ZRecordState] = [.needsWritable, .needsParent, .needsColor, .needsRoot]
        let         missingParents = parentIDsWithMatchingStates(states)
        let                orphans = recordIDsWithMatchingStates(states)
        let                  count = missingParents.count

        if  count > 0, let operation = configure(CKFetchRecordsOperation()) as? CKFetchRecordsOperation {
            var        recordsByID = [CKRecord : CKRecordID?] ()
            operation   .recordIDs = missingParents

            operation.perRecordCompletionBlock = { (iRecord: CKRecord?, iID: CKRecordID?, iError: Error?) in
                if self.detectError(iError, { gAlertManager.report(error: iError) } ) {
                    if iRecord != nil {
                        recordsByID[iRecord!] = iID
                    }
                }
            }

            operation.completionBlock = {
                self.FOREGROUND {
                    var forReport = [Zone] ()

                    for (iRecord, iID) in recordsByID {
                        var fetchedParent  = self.zoneForRecordID(iID)

                        if  fetchedParent != nil {
                            fetchedParent?.mergeIntoAndTake(iRecord) // BROKEN: likely this does not do what's needed here .... yikes! HUH?
                        } else {
                            fetchedParent  = self.zoneForRecord(iRecord)
                        }

                        if  let         p = fetchedParent {
                            let fetchedID = p.record.recordID

                            for orphan in orphans {
                                if  let  child = self.zoneForRecordID(orphan), let parentID = child.parentZone?.record.recordID, parentID == fetchedID {
                                    let states = self.states(for: child.record)

                                    if  child.isRoot || child == p {
                                        child.parentZone = nil

                                        child.needFlush()
                                    } else if !p.children.contains(child) {
                                        p.children.append(child)
                                    }

                                    if !forReport.contains(child) {
                                        forReport.append(child)
                                    }

                                    if  states.contains(.needsRoot) {
                                        p.maybeNeedRoot()
                                    }

                                    if  states.contains(.needsColor) {
                                        p.maybeNeedColor()
                                    }

                                    if  states.contains(.needsWritable) {
                                        p.needWritable()
                                    }

                                    p.maybeNeedChildren()
                                }
                            }
                        }
                    }
                    
                    self.columnarReport("PARENT of", self.stringForZones(forReport))
                    self.clearRecordIDs(orphans, for: states)
                    self.fetchParents(onCompletion)   // process remaining
                }
            }

            start(operation)
        } else {
            onCompletion?(0)
        }
    }


    func fetchChildren(_ iLogic: ZRecursionLogic? = ZRecursionLogic(.restore), _ onCompletion: IntClosure?) {
        let          logic = iLogic              ?? ZRecursionLogic(.restore)
        let  progenyNeeded = pullReferencesWithMatchingStates([.needsProgeny])
        let childrenNeeded = pullReferencesWithMatchingStates([.needsChildren]) + progenyNeeded
        let   destroyedIDs = recordIDsWithMatchingStates([.needsDestroy])
        let          count = childrenNeeded.count

        onCompletion?(count)

        if count > 0 {
            var  retrieved = [CKRecord] ()
            let  predicate = NSPredicate(format: "parent IN %@", childrenNeeded)

            columnarReport("CHILDREN of", stringForReferences(childrenNeeded, in: storageMode))
            queryWith(predicate) { (iRecord: CKRecord?) in
                if  let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means: we already received full response from cloud for this particular fetch
                    self.FOREGROUND {

                        ////////////////////////////
                        // now we can mutate heap //
                        ////////////////////////////

                        for record in retrieved {
                            let identifier = record.recordID
                            if  self.zoneForRecordID(identifier) != nil {
                                if destroyedIDs.contains(identifier) {
                                    // self.columnarReport(" DESTROYED", child.decoratedName)

                                    break // don't process/add destroyed zone
                                }
                            }

                            let  child = self.zoneForRecord(record)
                            let parent = child.parentZone

                            if  child.isRoot || parent == child {
                                child.parentZone = nil // fix a mysterious bug that causes a HANG ... a root can NOT be a child, by definition

                                child.needFlush()
                            } else {
                                logic.propagateNeeds(to: child, progenyNeeded)

                                if  let p = parent, !p.hasChildMatchingRecordName(of: child) {

                                    ///////////////////////////////////////
                                    // no child has matching record name //
                                    ///////////////////////////////////////

                                    if  let    link = child.crossLink,

                                        ///////////////////////////////////////////
                                        // bookmarks need fetch, color, writable //
                                        ///////////////////////////////////////////

                                        let    mode = link.storageMode {
                                        let manager = gRemoteStoresManager.recordsManagerFor(mode)
                                        var states: [ZRecordState] = [.needsColor, .needsWritable]

                                        if   !link.alreadyExists {
                                            states.append(.needsFetch)
                                        }

                                        manager.addRecord(link, for: states)
                                    }

                                    p.add(child)
                                    p.respectOrder()
                                }
                            }
                        }

                        self.add(states: [.needsCount], to: childrenNeeded)
                        self.fetchChildren(logic, onCompletion) // process remaining
                    }
                }
            }
        }
    }


    func fetchBookmarks(_ onCompletion: IntClosure?) {
        let recordIDs = recordIDsWithMatchingStates([.needsBookmarks], pull: true)
        let     count = recordIDs.count

        onCompletion?(count)

        if  count > 0 {
            let predicate = bookmarkPredicate(from: recordIDs)
            var retrieved = [CKRecord] ()

            queryWith(predicate) { iRecord in
                if let ckRecord = iRecord {
                    if !retrieved.contains(ckRecord) {
                        retrieved.append(ckRecord)
                    }
                } else { // nil means done
                    self.FOREGROUND {
                        for ckrecord in retrieved {
                            var record  = self.recordForCKRecord(ckrecord)

                            if  record == nil  {
                                record  = Zone(record: iRecord, storageMode: self.storageMode) // register
                            }
                        }

                        for identifier in recordIDs {
                            let record = self.recordForRecordID(identifier)

                            record?.unmarkForAllOfStates([.needsBookmarks])
                        }

                        if retrieved.count > 0 {
                            self.columnarReport("BOOKMARKS", self.stringForCKRecords(retrieved))
                        }

                        self.fetchBookmarks(onCompletion)    // process remaining
                    }
                }
            }
        }
    }


    func fetchCloudZones(_ onCompletion: IntClosure?) {
        if let                              operation = configure(CKFetchRecordZonesOperation()) as? CKFetchRecordZonesOperation {
            operation.fetchRecordZonesCompletionBlock = { (recordZonesByZoneID, operationError) in
                self.cloudZonesByID                   = recordZonesByZoneID!

                gRemoteStoresManager.resetBadgeCounter()

                onCompletion?(0)
            }

            start(operation)
            onCompletion?(-1)
        } else {
            onCompletion?(0)
        }
    }


    func establishHere(_ onCompletion: IntClosure?) {
        let manifest = gRemoteStoresManager.manifest(for: storageMode)

        let rootCompletion = {
            manifest.hereZone = gRoot!

            onCompletion?(0)
        }

        if manifest.here == nil { // first launch
            rootCompletion()
        } else {
            let recordID = manifest.here!.recordID

            self.assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iHereRecord: CKRecord?) in
                if iHereRecord == nil || iHereRecord?[gZoneNameKey] == nil {
                    rootCompletion()
                } else {
                    let          here = self.zoneForRecord(iHereRecord!)
                    here      .record = iHereRecord
                    manifest.hereZone = here

                    here.maybeNeedRoot()
                    here.needProgeny()
                    onCompletion?(0)
                }
            }
        }
    }


    func establishRoot(_ onCompletion: IntClosure?) {
        if rootZone != nil {
            establishTrash(onCompletion)
        } else {
            let recordID = CKRecordID(recordName: gRootNameKey)

            assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                var ckRecord  = iRecord
                if  ckRecord == nil {
                    ckRecord  = CKRecord(recordType: gZoneNameKey, recordID: recordID)
                }

                self.rootZone = self.zoneForRecord(ckRecord!)    // get / create root7

                if  self.rootZone?.zoneName == nil {
                    self.rootZone?.zoneName = "title"
                }

                self.rootZone?.needFlush()
                self.rootZone?.needProgeny()
                self.establishTrash(onCompletion)
            }
        }
    }


    func establishTrash(_ onCompletion: IntClosure?) {
        if trashZone != nil {
            onCompletion?(0)
        } else {
            let recordID = CKRecordID(recordName: gTrashNameKey)

            assureRecordExists(withRecordID: recordID, recordType: gZoneTypeKey) { (iRecord: CKRecord?) in
                if iRecord != nil {
                    let      trash = self.zoneForRecord(iRecord!)    // get / create trash
                    trash.zoneName = gTrashNameKey
                    self.trashZone = trash

                    trash.needChildren()
                }

                onCompletion?(0)
            }
        }
    }


    // MARK:- remote persistence
    // MARK:-


    func unsubscribe(_ onCompletion: IntClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            onCompletion?(-1)
            database!.fetchAllSubscriptions { (iSubscriptions: [CKSubscription]?, iError: Error?) in
                if self.detectError(iError, { onCompletion?(0); gAlertManager.report(error: iError) } ) {
                    var count: Int = iSubscriptions!.count

                    if count == 0 {
                        onCompletion?(0)
                    } else {
                        for subscription: CKSubscription in iSubscriptions! {
                            self.database!.delete(withSubscriptionID: subscription.subscriptionID, completionHandler: { (iSubscription: String?, iUnsubscribeError: Error?) in
                                self.detectError(iUnsubscribeError) { gAlertManager.report(error: iUnsubscribeError) }

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


    func subscribe(_ onCompletion: IntClosure?) {
        if  database == nil {
            onCompletion?(0)
        } else {
            let classNames = [gZoneTypeKey, gManifestTypeKey]
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
                    self.detectError (iSubscribeError) {
                        self.signalFor(iSubscribeError as NSObject?, regarding: .error)
                        gAlertManager.report(error: iSubscribeError)
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
                if  self.detectError(performanceError, { self.signalFor(performanceError as NSObject?, regarding: .error) } ) {
                    let        record: CKRecord = (iResults?[0])!
                    object.record[valueForPropertyName] = (record as! CKRecordValue)

                    self.signalFor(nil, regarding: .redraw)
                }
            }
        }
    }
}

