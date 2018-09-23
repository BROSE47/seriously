//
//  ZLockManager.swift
//  Zones
//
//  Created by Jonathan Sand on 6/1/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation


class ZLockManager: NSObject {


    var current: Foundation.OperationQueue? { return Foundation.OperationQueue.current }
    var queue:   Foundation.OperationQueue? = nil
    let semaphore                           = DispatchSemaphore(value: 0)


    func borrow(block: Closure) {
        wait()
        block()
        proceed()
    }


    @discardableResult func wait() -> Bool {
        let forcedToWait = queue != nil

        if  current     != queue {
            if forcedToWait {
                semaphore.wait()
            }

            if queue != nil {
                report("\(queue!) =======> \(current!)")
            }

            queue = current
        }

        return forcedToWait
    }


    func proceed() {
        if  queue == current {
            let result = semaphore.signal()

            if result < 0 {
                report("unlock failed: \(result)")
            }

            queue = nil
        }
    }
}