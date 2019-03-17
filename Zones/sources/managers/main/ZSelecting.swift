//
//  ZSelecting.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 11/20/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


enum ZRelation: Int {
    case above
    case below
    case upon
}


let gSelecting = ZSelecting()


class ZSnapshot: NSObject {

    
    var currentGrabs = [Zone] ()
    var   databaseID : ZDatabaseID?
    var         here : Zone?
    var       isSame : Bool { return gSelecting.snapshot == self }


    static func == ( left: ZSnapshot, right: ZSnapshot) -> Bool {
        let   goodIDs = left.databaseID != nil && right.databaseID != nil
        let  goodHere = left      .here != nil && right      .here != nil
        let sameCount = left.currentGrabs.count == right.currentGrabs.count

        if  goodHere && goodIDs && sameCount {
            let sameHere = left.here == right.here
            let  sameIDs = left.databaseID == right.databaseID

            if  sameHere && sameIDs {
                for (index, grab) in left.currentGrabs.enumerated() {
                    if  grab != right.currentGrabs[index] {
                        return false
                    }
                }

                return true
            }
        }

        return false
    }

}


class ZSelecting: NSObject {


    var         hasGrab :  Bool  { return currentGrabs.count > 0 }
    var        lastGrab :  Zone  { return  lastGrab() }
    var       firstGrab :  Zone  { return firstGrab() }
    var  lastSortedGrab :  Zone  { return  lastGrab(using: sortedGrabs) }
    var firstSortedGrab :  Zone  { return firstGrab(using: sortedGrabs) }
    var      cousinList : [Zone] { get { maybeNewGrabUpdate(); return _cousinList  } set { _cousinList  = newValue }}
    var     sortedGrabs : [Zone] { get { updateSortedGrabs();  return _sortedGrabs } set { _sortedGrabs = newValue }}
    var  pasteableZones = [Zone: (Zone?, Int?)] ()
    var    currentGrabs = [Zone] ()
    var    _sortedGrabs = [Zone] ()
    var     _cousinList = [Zone] ()
    var      hasNewGrab :  Zone?


    var snapshot : ZSnapshot {
        let          snap = ZSnapshot()
        snap.currentGrabs = currentGrabs
        snap  .databaseID = gDatabaseID
        snap        .here = gCloud?.hereIsValid ?? false ? gHere : nil

        return snap
    }


    var writableGrabsCount: Int {
        var count = 0

        for zone in currentGrabs {
            if zone.isTextEditable {
                count += 1
            }
        }

        return count
    }


    var simplifiedGrabs: [Zone] {
        let current = currentGrabs
        var   grabs = [Zone] ()

        for grab in current {
            var found = false

            grab.traverseAncestors { iZone -> ZTraverseStatus in
                if  grab != iZone && current.contains(iZone) {
                    found = true

                    return .eStop
                }

                return .eContinue
            }

            if !found {
                grabs.append(grab)
            }
        }

        return grabs
    }


    var currentGrabsHaveVisibleChildren: Bool {
        for     grab in currentGrabs {
            if  grab.count > 0 &&
                grab.showingChildren {
                return true
            }
        }

        return false
    }


    var grabbedColor: ZColor {
        get { return firstGrab.color }
        set {
            for grab in currentGrabs {
                grab.color = newValue
            }
        }
    }
    

    var rootMostMoveable: Zone {
        var candidate = currentMoveable

        for grabbed in currentGrabs {
            if  grabbed.level < candidate.level {
                candidate = grabbed
            }
        }

        return candidate
    }
    
    
    var currentMoveableLine: Zone? {
        for grab in currentGrabs + [gHere] {
            if grab.zoneName?.isLineWithTitle ?? false {
                return grab
            }
        }
        
        return nil
    }


    var currentMoveable: Zone {
        var movable: Zone?

        if  currentGrabs.count > 0 {
            movable = firstGrab
        } else if let zone = gTextEditor.currentlyEditingZone {
            movable = zone
        }

        if  movable == nil {
            movable = gHere
        }

        return movable!
    }
    

    // MARK:- convenience
    // MARK:-


    func isSelected(_ zone: Zone) -> Bool { return isGrabbed(zone) || gTextEditor.currentlyEditingZone == zone }
    func isGrabbed (_ zone: Zone) -> Bool { return currentGrabs.contains(zone) }
    func updateBrowsingLevel()            { gCurrentBrowseLevel = currentMoveable.level }
    func clearPaste()                     { pasteableZones = [:] }
    
    
    func updateAfterMove() {
        updateBrowsingLevel()
        updateCousinList()
        gFavorites.updateFavoritesRedrawSyncRedraw()
    }
    
    
    func assureMinimalGrabs() {
        if  currentGrabs.count == 0 {
            grab([gHere])
        }
    }


    func setHereRecordName(_ iName: String, for databaseID: ZDatabaseID) {
        if  let         index = databaseID.index {
            var    references = gHereRecordNames.components(separatedBy: kSeparator)
            references[index] = iName
            gHereRecordNames  = references.joined(separator: kSeparator)
        }
    }


    func hereRecordName(for databaseID: ZDatabaseID) -> String? {
        let references = gHereRecordNames.components(separatedBy: kSeparator)

        if  let  index = databaseID.index {
            return references[index]
        }

        return nil
    }

    
    // MARK:- selection
    // MARK:-


    func ungrabAll(retaining: [Zone]? = nil) {
        let    isEmpty = retaining == nil || retaining!.count == 0
        let       more = isEmpty ? [] : retaining!
        let    grabbed = currentGrabs + more
        currentGrabs   = []
        sortedGrabs    = []
        cousinList     = []

        if !isEmpty {
            hasNewGrab = more[0]
        }
        
        currentGrabs.append(contentsOf: more)

        for zone in grabbed {
            if  let widget = zone.widget {
                widget.dragDot.innerDot?.setNeedsDisplay()
                widget                  .setNeedsDisplay()
            }
        }
    }
    
    
    func maybeClearBrowsingLevel() {
        if  currentGrabs.count == 0 {
            gCurrentBrowseLevel = nil
        }
    }


    func updateWidgetFor(_ zone: Zone?) {
        if  zone != nil, let widget = zone!.widget {
            widget                  .setNeedsDisplay()
            widget.dragDot.innerDot?.setNeedsDisplay()
        }
    }


    func ungrab(_ iZone: Zone?) {
        if let zone = iZone, let index = currentGrabs.index(of: zone) {
            currentGrabs.remove(at: index)
            updateWidgetFor(zone)
            maybeClearBrowsingLevel()
        }
    }


    func respectOrder(for zones: [Zone]) -> [Zone] {
        return zones.sorted { (a, b) -> Bool in
            return a.order < b.order || a.level < b.level // compare levels from multiple parents
        }
    }


    func addMultipleGrabs(_ iZones: [Zone]) {
        for zone in iZones {
            addOneGrab(zone)
        }
    }


    func addOneGrab(_ iZone: Zone?, single: Bool = false) {
        if  let zone = iZone,
            (!currentGrabs.contains(zone) || single) { // if onlyOne AND already grabbed, shrink grab list to iZone
            gTextEditor.stopCurrentEdit()

            if  single {
                ungrabAll()
                
                hasNewGrab = zone
            }

            currentGrabs.append(zone)

            currentGrabs = respectOrder(for: currentGrabs)

            for grab in currentGrabs {
                updateWidgetFor(grab)
            }
        }
    }
    
    
    func makeVisibleAndGrab(_ iZone: Zone?, updateBrowsingLevel: Bool = true) {
        makeVisible(iZone, updateBrowsingLevel: updateBrowsingLevel) {
            iZone?.grab()
        }
    }
    
    
    func makeVisible(_ iZone: Zone?, updateBrowsingLevel: Bool = true, onCompletion: Closure?) {
        if  let zone = iZone,
            let dbID = zone.databaseID,
            let target = gRemoteStorage.cloud(for: dbID)?.hereZone {
            zone.traverseAncestors { iAncestor -> ZTraverseStatus in
                if  iAncestor != zone {
                    iAncestor.revealChildren()
                }
                
                if  iAncestor == target {
                    return .eStop
                }
                
                return .eContinue
            }
            
            onCompletion?()
        }
    }
    
    
    func grab(_ iZones: [Zone]?, updateBrowsingLevel: Bool = true) {
        if  let zones = iZones {
            ungrabAll()
            addMultipleGrabs(zones)
            
            if  updateBrowsingLevel,
                let rootMost = zones.rootMost {
                gCurrentBrowseLevel = rootMost.level
            }
        }
    }
    
    
    private func firstGrab(using: [Zone]? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
        let count = grabs.count
        var grabbed: Zone?
        
        if  count > 0 {
            grabbed = grabs[0]
        }
        
        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }
        
        return grabbed!
    }
    
    
    private func lastGrab(using: [Zone]? = nil) -> Zone {
        let grabs = using == nil ? currentGrabs : using!
        let count = grabs.count
        var grabbed: Zone?
        
        if  count > 0 {
            grabbed = grabs[count - 1]
        }
        
        if  grabbed == nil || grabbed!.record == nil {
            grabbed = gHere
        }
        
        return grabbed!
    }


    func deselectGrabsWithin(_ zone: Zone) {
        zone.traverseAllProgeny { iZone in
            if iZone != zone && currentGrabs.contains(iZone), let index = currentGrabs.index(of: iZone) {
                currentGrabs.remove(at: index)
            }
        }
    }


    // MARK:- internals
    // MARK:-

    
    func maybeNewGrabUpdate() {
        if  let grab = hasNewGrab {
            hasNewGrab = nil

            updateCousinList(for: grab)
        }
    }
    
    
    func updateCousinList(for iZone: Zone? = nil) {
        _cousinList.removeAll()
        _sortedGrabs.removeAll()
        
        if  let level =  gCurrentBrowseLevel {
            let  zone = iZone != nil ? iZone! : firstGrab
            let start =  zone.isInFavorites ? gFavoritesRoot : gHere
            start?.traverseAllVisibleProgeny { iChild in
                if   iChild.level == level ||
                    (iChild.level  < level && (iChild.count == 0 || !iChild.showingChildren)) {
                    _cousinList.append(iChild)
                }
                
                if  currentGrabs.contains(iChild) {
                    _sortedGrabs.append(iChild)
                }
            }
        }
    }
    
    
    func updateSortedGrabs() {
        _sortedGrabs.removeAll()
        
        let  zone = firstGrab
        let start = zone.isInFavorites ? gFavoritesRoot : gHere

        start?.traverseAllVisibleProgeny { iChild in
            if  currentGrabs.contains(iChild) {
                _sortedGrabs.append(iChild)
            }
        }
    }
    
}
