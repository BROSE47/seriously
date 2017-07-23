//
//  ZManifest.swift
//  Zones
//
//  Created by Jonathan Sand on 12/3/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


class ZManifest: ZRecord {


    dynamic var here:    CKReference?
    var        _hereZone:       Zone?
    var         currentGrabs = [Zone] ()
    var   manifestMode: ZStorageMode?


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(here)]
    }


    var hereZone: Zone {
        get {
            if _hereZone == nil {
                let hereRecord: CKRecord? = (here == nil) ? nil : CKRecord(recordType: zoneTypeKey, recordID: (here?.recordID)!)
                _hereZone                 = Zone(record: hereRecord, storageMode: manifestMode)
            }

            return _hereZone!
        }

        set {
            if  _hereZone != newValue {
                _hereZone  = newValue
            }

            if let record = _hereZone?.record, record.recordID.recordName != here?.recordID.recordName {
                here = CKReference(record: record, action: .none)

                needSave()
            }
        }
    }


    override func markForAllOfStates (_ states: [ZRecordState]) {
        if manifestMode != .favorites {
            super.markForAllOfStates(states)
        }
    }

}