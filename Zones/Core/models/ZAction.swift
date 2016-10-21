//
//  ZAction.swift
//  Zones
//
//  Created by Jonathan Sand on 8/28/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation
import CloudKit


class ZAction: ZBase {

    var action: NSDictionary?
    var  owner: Zone?


    override func cloudProperties() -> [String] {
        return super.cloudProperties() + [#keyPath(action), #keyPath(owner)]
    }
}
