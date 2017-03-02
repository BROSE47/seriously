//
//  ZRecordsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 12/4/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


enum ZRecordState: Int {
    case needsSave
    case needsMerge
    case needsFetch
    case needsCreate
    case needsParent
    case needsChildren
}


class ZRecordsManager: NSObject {


    var statesByMode = [ZStorageMode : [ZRecordState : [ZRecord]]] ()
    var zoneRegistry = [ZStorageMode : [String       :      Zone]] ()


    var recordsByState: [ZRecordState : [ZRecord]] {
        set {
            statesByMode[gStorageMode] = newValue
        }

        get {
            if statesByMode[gStorageMode] == nil {
                self.recordsByState = [:]
            }

            return statesByMode[gStorageMode]!
        }
    }


    var zones: [String : Zone] {
        set {
            zoneRegistry[gStorageMode] = newValue
        }

        get {
            var registry: [String : Zone]? = zoneRegistry[gStorageMode]

            if registry == nil {
                registry   = [:]
                self.zones = registry!
            }

            return registry!
        }
    }


    var allStates: [ZRecordState] {
        get {
            var states = [ZRecordState] ()

            for state in recordsByState.keys {
                states.append(state)
            }

            return states
        }
    }


    var bookmarks: [Zone] {
        get {
            var bookmarks = [Zone] ()

            for mode: ZStorageMode in [.mine, .everyone, .favorites] {
                invokeWithMode(mode) {
                    for zone in zones.values {
                        if zone.isBookmark {
                            bookmarks.append(zone)
                        }
                    }
                }
            }

            return bookmarks
        }
    }


    // MARK:- record state
    // MARK:-


    func recordsForState(_ state: ZRecordState) -> [ZRecord] {
        let    dict = recordsByState    // note: statesByMode is a dictionary of dictionaries
        var records = dict[state]       // swift's terse nature has confused me, here

        if records == nil {
            records = []

            recordsByState[state] = records
        }

        return records!
    }


    func clear() {
        recordsByState = [:]
    }


    func findRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState], onEach: StateRecordClosure?) {
        if iRecordID != nil {
            for state in forStates {
                for record in recordsForState(state) {
                    if record.record != nil && record.record.recordID.recordName == iRecordID?.recordName {
                        onEach?(state, record)
                    }
                }
            }
        }
    }


    func hasRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) -> Bool {
        var found = false

        findRecordByRecordID(iRecord.record?.recordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            found = true
        })

        return found
    }


    func addRecord(_ iRecord: ZRecord, forStates: [ZRecordState]) {
        for state in forStates {
            if !hasRecord(iRecord, forStates: [state]) {
                var records = recordsForState(state)

                records.append(iRecord)

                recordsByState[state] = records
            }
        }

    }

    func removeRecordByRecordID(_ iRecordID: CKRecordID?, forStates: [ZRecordState]) {
        findRecordByRecordID(iRecordID, forStates: forStates, onEach: { (state: ZRecordState, record: ZRecord) in
            var records = self.recordsForState(state)

            if let index = records.index(of: record) {
                records.remove(at: index)

                self.recordsByState[state] = records
            }
        })
    }


    func clearRecord(_ iRecord: ZRecord) {
        removeRecordByRecordID(iRecord.record?.recordID, forStates: allStates)
    }


    func clearStates(_ states: [ZRecordState]) {
        for state in states {
            clearState(state)
        }
    }


    func clearState(_ state: ZRecordState) {
        recordsByState[state] = nil
    }


    func zoneNamesWithMatchingStates(_ states: [ZRecordState]) -> String {
        var names = [String] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: Zone = object as! Zone

            if let name = zone.zoneName, !names.contains(name) {
                names.append(name)
            }
        }

        return names.joined(separator: ", ")
    }


    func recordIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var identifiers = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: ZRecord = object as! ZRecord

            if let record = zone.record, !identifiers.contains(record.recordID) {
                identifiers.append(record.recordID)
            }
        }

        return identifiers
    }


    func parentIDsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecordID] {
        var parents = [CKRecordID] ()

        findRecordsWithMatchingStates(states) { object in
            let zone: Zone = object as! Zone

            if let reference = zone.parent {
                let parentID = reference.recordID

                if !parents.contains(parentID) {
                    parents.append(parentID)
                }
            }
        }

        return parents
    }


    func recordsWithMatchingStates(_ states: [ZRecordState]) -> [CKRecord] {
        var objects = [CKRecord] ()

        findRecordsWithMatchingStates(states) { object in
            let  zone: ZRecord = object as! ZRecord

            if let      record = zone.record, !objects.contains(record) {
                zone.debug("saving")

                objects.append(record)
            }
        }

        return objects
    }


    func referencesWithMatchingStates(_ states: [ZRecordState]) -> [CKReference] {
        var references = [CKReference] ()

        findRecordsWithMatchingStates(states) { object in
            if  let    record:     ZRecord = object as? ZRecord, record.record != nil {
                let reference: CKReference = CKReference(recordID: record.record.recordID, action: .none)

                references.append(reference)
            }
        }

        return references
    }


    func findRecordsWithMatchingStates(_ states: [ZRecordState], onEach: ObjectClosure) {
        for state in states {
            let records = recordsForState(state)

            for record in records {
                onEach(record)
            }
        }
    }


    // MARK:- zones registry
    // MARK:-


    func isRegistered(_ zone: Zone) -> String? {
        if zones.values.contains(zone) {
            for name in zones.keys {
                let examined = zones[name]

                if examined?.hash == zone.hash {
                    return name
                }
            }
        }

        return nil
    }


    func registerZone(_ zone: Zone?) {
        if  let     record = zone?.record {
            let registered = isRegistered(zone!)
            let identifier = record.recordID.recordName

            if registered == nil {
                zones[identifier]  = zone
                let       manifest = gTravelManager.manifest
                let          total = zones.count

                if  manifest.total < total {
                    manifest.total = total

                    manifest.needUpdateSave()
                }
            } else if registered! != identifier {
                zones[registered!] = nil
                zones[identifier]  = zone
            }
        }
    }


    func unregisterZone(_ zone: Zone?) {
        if let record = zone?.record {
            zones[record.recordID.recordName] = nil
        }
    }


    func bookmarksFor(_ zone: Zone?) -> [Zone] {
        var zoneBookmarks = [Zone] ()

        if zone != nil, let recordID = zone?.record?.recordID {
            for bookmark in bookmarks {
                if let identifier = bookmark.crossLink?.record?.recordID, recordID == identifier {
                    zoneBookmarks.append(bookmark)
                }
            }
        }

        return zoneBookmarks
    }


    func recordForRecordID(_ recordID: CKRecordID?) -> ZRecord? {
        var record = zoneForRecordID(recordID) as ZRecord?

        if record == nil {
            if gTravelManager.manifest.record?.recordID.recordName == recordID?.recordName {
                record = gTravelManager.manifest
            }
        }

        return record
    }


    func zoneForReference(_ reference: CKReference) -> Zone? {
        var zone = zones[reference.recordID.recordName]

        if  zone == nil, let record = recordForRecordID(reference.recordID)?.record {
            zone = Zone(record: record, storageMode: gStorageMode)
        }

        return zone
    }


    func zoneForRecord(_ record: CKRecord) -> Zone {
        var zone = zones[record.recordID.recordName]

        if zone == nil {
            zone = Zone(record: record, storageMode: gStorageMode)
        } else if !(zone?.isDeleted ?? false) {
            zone?.record = record
        }

        if  zone!.showChildren || zone!.hasChildren {
            zone!.needChildren()
        }

        return zone!
    }


    func zoneForRecordID(_ recordID: CKRecordID?) -> Zone? {
        if recordID == nil {
            return nil
        }
        
        return zones[recordID!.recordName]
    }
}
