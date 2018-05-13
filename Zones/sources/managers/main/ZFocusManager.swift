//
//  ZFocusManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


let gFocusManager = ZFocusManager()


class ZFocusManager: NSObject {


    var  travelStack = [Zone] ()
    var currentIndex = -1
    var   priorIndex = -1
    var     topIndex : Int  { return travelStack.count - 1 }
    var       atHere : Bool { return currentIndex >= 0 && gHere == travelStack[currentIndex] }


    // MARK:- travel stack
    // MARK:-


    var isInStack : Int? {
        let     here  = gHere

        for (index, zone) in travelStack.enumerated() {
            if  here == zone {
                return index
            }
        }

        return nil
    }


    func debugDump() {
        for (index, zone) in travelStack.enumerated() {
            let isCurrentIndex = index == currentIndex
            let prefix = isCurrentIndex ? " •" : ""
            columnarReport(prefix, zone.decoratedName)
        }
    }


    func pushHere() {
        var newIndex  = currentIndex + 1

        if topIndex  < 0 || !atHere {
            if  let index = isInStack {
                newIndex  = index   // prevent duplicates in stack
            } else if  topIndex == currentIndex {
                travelStack.append(gHere)
            } else {
                if  currentIndex < 0 {
                    currentIndex = 0
                }

                travelStack.insert(gHere, at: currentIndex)
            }

            currentIndex = newIndex
        }
    }


    func goBack(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if !atHere {
            pushHere()
        }

        if currentIndex <= 0 {
            currentIndex = topIndex
        } else if extreme {
            currentIndex = 0
        } else if currentIndex == topIndex || atHere {
            currentIndex -= 1
        }

        go()
    }


    func goForward(extreme: Bool = false) {
        if  let    index = isInStack {
            currentIndex = index
        } else if !atHere {
            pushHere()
        }

        if  currentIndex == topIndex {
            currentIndex  = 0
        } else if  extreme {
            currentIndex = topIndex
        } else if  currentIndex < topIndex {
            currentIndex += 1
        }

        go()
    }


    func go() {
        if  0          <= currentIndex, (!atHere ||
            priorIndex != currentIndex) {
            priorIndex  = currentIndex
            let dbID    = gHere.databaseID
            let here    = travelStack[currentIndex]
            if  dbID   != here.databaseID {
                toggleDatabaseID()         // update id before setting gHere
            }

            gHere       = here

            debugDump()
            gHere.grab()
            gFavoritesManager.updateFavorites()
            signalFor(nil, regarding: .redraw)
        }
    }


    // MARK:- travel
    // MARK:-


    func createUndoForTravelBackTo(_ zone: Zone, atArrival: @escaping Closure) {
        let   restoreID = gDatabaseID
        let restoreHere = gHere

        UNDO(self) { iUndoSelf in
            iUndoSelf.createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)
            iUndoSelf.pushHere()
            self.debugDump()

            gDatabaseID = restoreID

            iUndoSelf.focus {
                gHere = restoreHere

                zone.grab()
                atArrival()
            }
        }
    }


    func focus(_ atArrival: @escaping Closure) {
        createUndoForTravelBackTo(gSelectionManager.currentMoveable, atArrival: atArrival)

        gTextManager.stopCurrentEdit()
        gBatchManager.focus { iSame in
            atArrival()
            gBatchManager.save { iSaveSame in
            }
        }
    }


    @discardableResult func focus(through iBookmark: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iBookmark, bookmark.isBookmark {
            if  bookmark.isInFavorites {
                let targetParent = bookmark.bookmarkTarget?.parentZone
                let       parent = bookmark.parentZone

                targetParent?.revealChildren()
                targetParent?.needChildren()
                parent?.revealChildren()
                parent?.needChildren()
                travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    gFavoritesManager.updateFavorites()
                    atArrival()
                }

                return true
            } else if let dbID = bookmark.crossLink?.databaseID {
                pushHere()
                debugDump()

                gDatabaseID = dbID

                focus {
                    gHere.grab()
                    atArrival()
                }

                return true
            }

            performance("oops!")
        }

        return false
    }


    func travelThrough(_ iBookmark: Zone, atArrival: @escaping SignalClosure) {
        if  let      crossLink = iBookmark.crossLink,
            let           dbID = crossLink.databaseID,
            let         record = crossLink.record {
            let recordIDOfLink = record.recordID
            var   there: Zone? = nil

            if iBookmark.isFavorite {
                gFavoritesManager.currentFavorite = iBookmark
            }

            pushHere()
            debugDump()

            if  gDatabaseID  != dbID {
                gDatabaseID   = dbID

                /////////////////////////////////
                // TRAVEL TO A DIFFERENT GRAPH //
                /////////////////////////////////

                if iBookmark.bookmarkTarget!.isFetched { // e.g., default root favorite
                    focus {
                        gHere = iBookmark.bookmarkTarget!

                        gHere.prepareForArrival()
                        atArrival(gHere, .redraw)
                    }
                } else {
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord {
                            gHere          = gCloudManager.zoneForCKRecord(hereRecord)

                            gHere.prepareForArrival()
                            self.focus {
                                atArrival(gHere, .redraw)
                            }
                        } else {
                            atArrival(gHere, .redraw)
                        }
                    }
                }
            } else {

                ///////////////////////
                // STAY WITHIN GRAPH //
                ///////////////////////

                there = gCloudManager.maybeZoneForRecordID(recordIDOfLink)
                let grabbed = gSelectionManager.firstGrab
                let    here = gHere

                UNDO(self) { iUndoSelf in
                    self.UNDO(self) { iRedoSelf in
                        self.travelThrough(iBookmark, atArrival: atArrival)
                    }

                    gHere = here

                    grabbed.grab()
                    atArrival(here, .redraw)
                }

                let grabHere = {
                    gHere.prepareForArrival()

                    gBatchManager.children(.restore) { iSame in
                        atArrival(gHere, .redraw)
                    }
                }

                if  there != nil {
                    gHere = there!

                    grabHere()
                } else if gCloudManager.databaseID != .favoritesID { // favorites does not have a cloud database
                    gCloudManager.assureRecordExists(withRecordID: recordIDOfLink, recordType: kZoneType) { (iRecord: CKRecord?) in
                        if  let hereRecord = iRecord {
                            gHere          = gCloudManager.zoneForCKRecord(hereRecord)

                            grabHere()
                        }
                    }
                } // else ... favorites id with an unresolvable bookmark target
            }
        }
    }


    func maybeTravelThrough(_ iZone: Zone, onCompletion: Closure?) {
        if     !travelThroughBookmark(iZone, onCompletion: onCompletion) {
            if !travelThroughHyperlink(iZone) {
                travelThroughEmail(iZone)
            }
        }
    }


    @discardableResult func travelThroughEmail(_ iZone: Zone) -> Bool {
        if  let link  = iZone.email {
            let email = "mailTo:" + link
            email.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func travelThroughHyperlink(_ iZone: Zone) -> Bool {
        if  let link = iZone.hyperLink,
            link    != kNullLink {
            link.openAsURL()

            return true
        }

        return false
    }


    @discardableResult func travelThroughBookmark(_ bookmark: Zone, onCompletion: Closure?) -> Bool {
        let doThis = bookmark.isBookmark

        if  doThis {
            travelThrough(bookmark) { object, kind in
                onCompletion?()
            }
        }

        return doThis
    }

}