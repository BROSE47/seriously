//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZTraitType: String {
    case eComposition = "c"
    case eDuration    = "d" // accumulative
    case eEmail       = "e"
    case eGraphic     = "g"
    case eHyperlink   = "h"
    case eMoney       = "m" // accumulative
    case eTime        = "t"
}


class ZTrait: ZRecord {

    
    dynamic var  type: String?
    dynamic var  text: String?
    dynamic var  data: Data?
    dynamic var asset: CKAsset?
    dynamic var owner: CKReference?
    var _traitType: ZTraitType? = nil
    var _ownerZone: Zone? = nil


    var traitType: ZTraitType? {
        get {
            if  _traitType == nil, type != nil {
                _traitType  = ZTraitType(rawValue: type!)
            }

            return _traitType
        }

        set {
            if newValue != _traitType {
                _traitType = newValue
                type       = newValue?.rawValue
            }
        }
    }


    var ownerZone: Zone? {
        if  _ownerZone == nil {
            _ownerZone  = cloudManager?.maybeZRecordForRecordID(owner?.recordID) as? Zone
        }

        return _ownerZone
    }


    convenience init(databaseiD: ZDatabaseiD?) {
        self.init(record: CKRecord(recordType: kTraitType), databaseiD: databaseiD)
    }
    

    class func cloudProperties() -> [String] {
        return[#keyPath(type),
               #keyPath(data),
               #keyPath(text),
               #keyPath(owner),
               #keyPath(asset)]
    }


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + ZTrait.cloudProperties()
    }


    override func unorphan() {
        if  let traits = ownerZone?.traits, let t = traitType, traits[t] == nil {
            ownerZone?.traits[t] = self
        }
    }

}
