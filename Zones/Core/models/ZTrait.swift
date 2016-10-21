//
//  ZTrait.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZTrait: ZBase {

    var  type: String?
    var value: Data?
    var owner: Zone?


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(type), #keyPath(value), #keyPath(owner)]
    }
}
