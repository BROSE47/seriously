//
//  ZBatches.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/21/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation

let gBatches        = ZBatches()
var gUser           :   ZUser? { return gBatches.user }
var gIsMasterAuthor :     Bool { return gBatches.isMasterAuthor }

enum ZBatchID: Int {
    case bRoot
    case bSync
    case bFocus
    case bStartUp
    case bRefetch
    case bUndelete
    case bFinishUp
    case bUserTest
    case bBookmarks
    case bFetchLost
    case bEmptyTrash
    case bNewAppleID
    case bResumeCloud
	case bSaveToCloud

    var shouldIgnore: Bool {
        switch self {
        case .bSync,
             .bStartUp,
             .bRefetch,
             .bFinishUp,
             .bNewAppleID,
             .bResumeCloud: return false
        case .bSaveToCloud: return gCanAccessMyCloudDatabase
        default:            return true
        }
    }

}

class ZBatches: ZOnboarding {

    class ZBatchCompletion: NSObject {
        var completion : BooleanClosure?
        var   snapshot : ZSnapshot

        override init() {
            snapshot = gSelecting.snapshot
        }

        convenience init(_ iClosure: @escaping BooleanClosure) {
            self.init()

            completion = iClosure
        }


        func fire() {
            completion?(snapshot.isSame)
        }
    }

    class ZBatch: NSObject {
        var       completions : [ZBatchCompletion]
        var        identifier :  ZBatchID
        var allowedOperations : [ZOperationID] { return gHasInternet ? operations : localOperations }

        var operations: [ZOperationID] {
            switch identifier {
            case .bSaveToCloud: return [                                    .oSaveToCloud          ]
            case .bFetchLost:   return [.oFetchLost,                        .oSaveToCloud,         ]
			case .bRefetch:     return [             .oFetchAll, .oRecount, .oSaveToCloud, .oTraits]
            case .bResumeCloud: return [             .oFetchAll,            .oSaveToCloud, .oTraits]
            case .bSync:        return [             .oFetchNeeded,         .oSaveToCloud, .oTraits]
            case .bBookmarks:   return [.oBookmarks, .oFetchNeeded,         .oSaveToCloud, .oTraits]
            case .bUndelete:    return [.oUndelete,  .oFetchNeeded,         .oSaveToCloud, .oTraits]
			case .bRoot:        return [.oRoots,        .oManifest,         .oSaveToCloud, .oTraits]
			case .bFocus:       return [.oRoots,     .oFetchNeeded,                        .oTraits]
			case .bEmptyTrash:  return [.oEmptyTrash                                               ]
            case .bNewAppleID:  return operationIDs(from: .oCheckAvailability, to: .oSubscribe, skipping: [.oReadFile])
            case .bStartUp:     return operationIDs(from: .oStartUp,           to: .oFinishUp)
            case .bFinishUp:    return operationIDs(from: .oFinishUp,          to: .oDone)
            case .bUserTest:    return operationIDs(from: .oObserveUbiquity,   to: .oFetchUserRecord)
            }
        }

        var localOperations : [ZOperationID] {
            var ids = [ZOperationID] ()

            for operation in operations {
                if operation.isLocal {
                    ids.append(operation)
                }
            }

            return ids
        }

        init(_ iID: ZBatchID, _ iCompletions: [ZBatchCompletion]) {
            completions = iCompletions
            identifier  = iID
        }

        func fireCompletions() {
            while let completion = completions.popLast() {
                completion.fire()
            }
        }

        func operationIDs(from: ZOperationID, to: ZOperationID, skipping: [ZOperationID] = []) -> [ZOperationID] {
            var operationIDs = [ZOperationID] ()

            for value in from.rawValue...to.rawValue {
                var add = true

                for     skip in skipping {
                    if  skip.rawValue == value {
                        add = false
                        
                        break
                    }
                }

                if  add {
                    operationIDs.append(ZOperationID(rawValue: value)!)
                }
            }

            return operationIDs
        }

    }

    var    currentBatches = [ZBatch] ()
    var   deferredBatches = [ZBatch] ()
    var currentDatabaseID : ZDatabaseID?
    var        totalCount :  Int { return currentBatches.count + deferredBatches.count }
    var            isLate : Bool { return lastOpStart != nil && lastOpStart!.timeIntervalSinceNow < -30.0 }

    // MARK:- API
    // MARK:-

    func       save(_ onCompletion: @escaping BooleanClosure) { batch(.bSaveToCloud, onCompletion) }
    func       root(_ onCompletion: @escaping BooleanClosure) { batch(.bRoot,        onCompletion) }
    func       sync(_ onCompletion: @escaping BooleanClosure) { batch(.bSync,        onCompletion) }
    func      focus(_ onCompletion: @escaping BooleanClosure) { batch(.bFocus,       onCompletion) }
    func    startUp(_ onCompletion: @escaping BooleanClosure) { batch(.bStartUp,     onCompletion) }
    func    refetch(_ onCompletion: @escaping BooleanClosure) { batch(.bRefetch,     onCompletion) }
    func   finishUp(_ onCompletion: @escaping BooleanClosure) { batch(.bFinishUp,    onCompletion) }
    func   undelete(_ onCompletion: @escaping BooleanClosure) { batch(.bUndelete,    onCompletion) }
    func   userTest(_ onCompletion: @escaping BooleanClosure) { batch(.bUserTest,    onCompletion) }
    func  bookmarks(_ onCompletion: @escaping BooleanClosure) { batch(.bBookmarks,   onCompletion) }
    func  fetchLost(_ onCompletion: @escaping BooleanClosure) { batch(.bFetchLost,   onCompletion) }
    func emptyTrash(_ onCompletion: @escaping BooleanClosure) { batch(.bEmptyTrash,  onCompletion) }

    func processNextBatch() {

        // 1. execute next current batch
        // 2. called by superclass, for each completion operation. fire completions and recurse
        // 3. no more current batches,                            transfer deferred and recurse
        // 4. no more batches, nothing to process

        FOREGROUND(canBeDirect: true) {
            if  let      batch = self.currentBatches.first {
                let operations = batch.allowedOperations

                self.setupAndRun(operations) {                  // 1.
                    batch.fireCompletions()                     // 2.
                    self.maybeRemoveFirst()
                    self.processNextBatch()
                }
            } else if self.deferredBatches.count > 0 {
                self.transferDeferred()                         // 3.
                self.processNextBatch()
            }                                                   // 4.
        }
    }

    func batch(_ iID: ZBatchID, _ iCompletion: @escaping BooleanClosure) {
        if  iID.shouldIgnore {
            iCompletion(true) // true means no new data
        } else {
            let     current = getBatch(iID, from: currentBatches)
            let completions = [ZBatchCompletion(iCompletion)]
            let   startOver = currentBatches.count == 0

            // 1. is in deferral            -> add its completion to that deferred batch
            // 2. in neither                -> create new batch + append to current
            // 3. in current +  no deferred -> add its completion to that current batch
            // 4. in current + has deferred -> create new batch + append to deferred (other batches may change the state to what it expects)

            if  let deferred = getBatch(iID, from: deferredBatches) {
                deferred.completions.append(contentsOf: completions)    // 1.
            } else if current == nil {
                currentBatches .append(ZBatch(iID, completions))        // 2.
            } else if deferredBatches.count > 0 {
                deferredBatches.append(ZBatch(iID, completions))        // 3.
            } else {
                current?.completions.append(contentsOf: completions)    // 4.
            }

            if  startOver {
                processNextBatch()
            }
        }
    }

    // MARK:- internals
    // MARK:-

    func getBatch(_ iID: ZBatchID, from iList: [ZBatch]) -> ZBatch? {
        for batch in iList {
            if  iID == batch.identifier {
                return batch
            }
        }

        return nil
    }

    func maybeRemoveFirst() {
        if  currentBatches.count > 0 {
            currentBatches.removeFirst()
        }
    }

    func transferDeferred() {

        // /////////////////////////////////////////////////////////
        // if current list is empty, transfer deferred to current //
        // /////////////////////////////////////////////////////////

        if  currentBatches.count == 0 && deferredBatches.count > 0 {
            currentBatches  = deferredBatches
            deferredBatches = []
        }
    }

    override func invokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        super.invokeMultiple(for: operationID, restoreToID: restoreToID) { iCompleted in

            // ///////////////////////////////////////////////////////////////
            //     first, allow onboarding superclass to perform block      //
            // iCompleted will be false if it does not handle the operation //
            // ///////////////////////////////////////////////////////////////

            if  iCompleted {
                onCompletion(true)
            } else {
                let              requiresActive = [.oSaveToCloud, .oTraits                ].contains(operationID)
                let               alwaysForBoth = [.oHere, .oRoots, .oReadFile, .oManifest].contains(operationID)
                let               forMineIDOnly = [.oBookmarks, .oSubscribe               ].contains(operationID)
                let                      isMine = restoreToID == .mineID
                let               onlyCurrentID = (!gCanAccessMyCloudDatabase && !alwaysForBoth) || operationID == .oCompletion
                let  databaseIDs: [ZDatabaseID] = forMineIDOnly ? [.mineID] : onlyCurrentID ? [restoreToID] : kAllDatabaseIDs
                let                      isNoop = !gCanAccessMyCloudDatabase && (requiresActive || (onlyCurrentID && isMine && operationID != .oFavorites))
                var invokeForIndex: IntClosure?                // declare closure first, so compiler will let it recurse
                invokeForIndex                  = { index in

                    // //////////////////////////////
                    // always called in foreground //
                    // //////////////////////////////

                    if  operationID == .oCompletion || isNoop || index >= databaseIDs.count {
                        onCompletion(true)
                    } else {
                        self.currentDatabaseID = databaseIDs[index]      // if hung, it happened in currentDatabaseID

                        self.invokeOperation(for: operationID) { (iResult: Any?) in

                            FOREGROUND(canBeDirect: true) {
                                let      error = iResult as? Error
                                let     result = iResult as? Int
                                let    isError = error != nil

                                if     isError || result == 0 {
                                    if isError {
										printDebug(.ops, "\(error!)")
                                    }

                                    invokeForIndex?(index + 1)         // recurse
                                }
                            }
                        }
                    }
                }

                invokeForIndex?(0)
            }
        }
    }

    override func invokeOperation(for identifier: ZOperationID, cloudCallback: AnyClosure?) {
        onCloudResponse = cloudCallback     // for retry cloud in tools controller

        switch identifier {
        case .oFavorites:                                                                          gFavorites.setup(cloudCallback)
        case .oReadFile: gFiles.readFile(into: currentDatabaseID!);                                                 cloudCallback?(0)
        default:     gRemoteStorage.cloud(for: currentDatabaseID!)?.invokeOperation(for: identifier, cloudCallback: cloudCallback)
        }
    }

}
