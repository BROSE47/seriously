//
//  XBGCD.m
//  Zones
//
//  Created by Jonathan Sand on 3/30/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation


extension NSObject {


    func FOREGROUND(_ closure: @escaping Closure) {
        DispatchQueue.main.async { closure() }
    }


    func BACKGROUND(_ closure: @escaping Closure) {
        DispatchQueue.global(qos: .background).async { closure() }
    }


    func FOREGROUND(after seconds: Double, closure: @escaping Closure) {
        let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

        DispatchQueue.main.asyncAfter(deadline: when) { closure() }
    }


    func BACKGROUND(after seconds: Double, closure: @escaping Closure) {
        let when = DispatchTime.now() + Double(Int64(seconds * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)

        DispatchQueue.global(qos: .background).asyncAfter(deadline: when) { closure() }
    }
}
