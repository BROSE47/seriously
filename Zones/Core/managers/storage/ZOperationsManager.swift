//
//  ZOperationsManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Foundation


class ZOperationsManager: NSObject {


    var    isReady:                                   Bool = false
    var operations: [ZSynchronizationState:BlockOperation] = [:]
    let      queue:                         OperationQueue = OperationQueue()
    var    onReady: Closure?



    func fullRun(_ block: (() -> Swift.Void)?) {
        onReady               = block
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.cloud.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates)
    }


    func travel(_ block: (() -> Swift.Void)?) {
        onReady               = block
        var syncStates: [Int] = []

        for sync in ZSynchronizationState.restore.rawValue...ZSynchronizationState.subscribe.rawValue {
            syncStates.append(sync)
        }

        setupAndRun(syncStates)
    }
    

    func setupAndRun(_ syncStates: [Int]) {
        queue.isSuspended                 = true
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService            = .background
        var states                        = syncStates
        var priorOp:      BlockOperation? = nil

        states.append(ZSynchronizationState.ready.rawValue)

        for state in states {
            let state = ZSynchronizationState(rawValue: state)!
            let    op = BlockOperation { self.invokeOn(state) }

            if priorOp != nil {
                op.addDependency(priorOp!)
            }

            priorOp           = op
            operations[state] = op

            queue.addOperation(op)
        }

        isReady           = false;
        queue.isSuspended = false
    }


    func invokeOn(_ state: ZSynchronizationState) {
        let operation = operations[state]!

        print(state)

        switch(state) {
        case .restore:     zfileManager.restore();        operation.finish();   break
        case .cloud:       cloudManager.fetchCloudZones { operation.finish() }; break
        case .root:        cloudManager.setupRoot       { operation.finish() }; break
        case .fetch:       cloudManager.fetch           { operation.finish() }; break
        case .children:    cloudManager.fetchChildren   { operation.finish() }; break
        case .unsubscribe: cloudManager.unsubscribe     { operation.finish() }; break
        case .subscribe:   cloudManager.subscribe       { operation.finish() }; break
        case .ready:       becomeReady(                   operation);           break
        }
    }


    func becomeReady(_ operation: BlockOperation) {
        isReady = true;

        operation.finish()

        if onReady != nil {
            onReady!()

            onReady = nil
        }
    }
}