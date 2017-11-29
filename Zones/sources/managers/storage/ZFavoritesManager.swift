//
//  ZFavoritesManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/24/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum ZFavoriteStyle: Int {
    case normal
    case favorite
    case addFavorite
}


let gFavoritesManager = ZFavoritesManager(.favoritesMode)


class ZFavoritesManager: ZCloudManager {


    // MARK:- initialization
    // MARK:-


    let defaultModes: ZModes = [.everyoneMode, .mineMode]
    let     defaultFavorites = Zone(record: nil, storageMode: .favoritesMode)
    var                count : Int  { return rootZone?.count ?? 0 }


    var hasTrash: Bool {
        if  let favorites = rootZone?.children {
            for favorite in favorites {
                if  let target = favorite.bookmarkTarget, target.isTrash {
                    return true
                }
            }
        }

        return false
    }


    var actionTitle: String {
        if  gHere.isGrabbed,
            let     target = currentFavorite?.bookmarkTarget {
            let isFavorite = gHere == target

            return isFavorite ? "Unfavorite" : "Favorite"
        }

        return "Focus"
    }


    var favoritesIndex: Int {
        return indexOf(currentFavoriteID) ?? 0
    }


    var currentFavoriteID: String? {
        get {
            if  let    identifier = UserDefaults.standard.object(forKey: currentFavoriteKey) as? String {
                return identifier
            }

            if  let initialID = zoneAtIndex(0)?.record.recordID.recordName {

                //////////////////////////////////////////////////////////////////////////////////////
                // initial default value is first item in favorites list, whatever it happens to be //
                //////////////////////////////////////////////////////////////////////////////////////

                UserDefaults.standard.set(initialID, forKey: currentFavoriteKey)

                return initialID
            }

            return nil
        }

        set {
            UserDefaults.standard.set(newValue, forKey: currentFavoriteKey)
        }
    }


    var currentFavorite: Zone? {
        get {
            return zoneAtIndex(favoritesIndex)
        }

        set {
            if  let identifier = newValue?.record.recordID.recordName {
                currentFavoriteID = identifier
            }
        }
    }


    // create an enumeration where favorites graphically below current
    // are ordered before those that are graphically above and equal

    var rotatedEnumeration: EnumeratedSequence<Array<Zone>> {
        let enumeration = rootZone?.children.enumerated()
        var     rotated = [Zone] ()

        for (index, favorite) in enumeration! {
            if  index >= favoritesIndex {
                rotated.append(favorite)
            }
        }

        for (index, favorite) in enumeration! {
            if  index < favoritesIndex {
                rotated.append(favorite)
            }
        }

        return rotated.enumerated()
    }


    private func zoneAtIndex(_ index: Int) -> Zone? {
        if index < 0 || rootZone == nil || index >= count {
            return nil
        }

        return rootZone?[index]
    }


    func indexOf(_ iFavoriteID: String?) -> Int? {
        if  let identifier = iFavoriteID, let enumeration = rootZone?.children.enumerated() {
            for (index, zone) in enumeration {
                if  zone.record.recordID.recordName == identifier {
                    return index
                }
            }
        }

        return nil
    }
    

    func favorite(for iTarget: Zone?, iSpawned: Bool = true) -> Zone? {
        var               found: Zone? = nil

        if  let              favorites = rootZone?.children,
            let                 target = iTarget,
            let                   mode = target.storageMode {
            var                  level = Int.max

            for favorite in favorites {
                if  let favoriteTarget = favorite.bookmarkTarget,
                    let     targetMode = favoriteTarget.storageMode,
                    targetMode        == mode {
                    let       newLevel = favoriteTarget.level
                    if        newLevel < level {
                        let    spawned = iSpawned ? target.spawned(favoriteTarget) : favoriteTarget.spawned(target)

                        if spawned {
                            level      = newLevel
                            found      = favorite
                        }
                    }
                }
            }
        }

        if iSpawned && found == nil {
            return favorite(for: iTarget, iSpawned: false)
        }

        return found
    }


    // MARK:- setup
    // MARK:-


    func setup() {
        if  gHasPrivateDatabase && rootZone == nil {
            let             record = CKRecord(recordType: gZoneTypeKey, recordID: CKRecordID(recordName: gFavoriteRootNameKey))
            rootZone               = Zone(record: record, storageMode: .mineMode)
            rootZone!    .zoneName = gFavoritesKey
            rootZone!.directAccess = .eChildrenWritable

            setupDefaultFavorites()
            rootZone!.needChildren()
            rootZone!.displayChildren()
        }
    }


    func setupDefaultFavorites() {
        if defaultFavorites.count == 0 {
            for (index, mode) in defaultModes.enumerated() {
                let          name = mode.rawValue
                let      favorite = create(withBookmark: nil, .addFavorite, parent: defaultFavorites, atIndex: index, name)
                favorite.zoneLink =  "\(name)\(gSeparatorKey)\(gSeparatorKey)"
                favorite   .order = Double(index) * 0.001

                favorite.clearAllStates()
            }
        }
    }


    // MARK:- API
    // MARK:-


    func updateChildren() {
        if  gHasPrivateDatabase {
            var trashCopies = IndexPath()
            var       found = ZModes ()
            var  foundTrash = false

            // assure at least one favorite per db
            // call every time favorites MIGHT be altered
            // end of handleKey in editor

            for favorite in defaultFavorites.children {
                rootZone?.removeSpawn(favorite)
            }

            rootZone?.traverseAllProgeny { iFavorite in
                if  let mode = iFavorite.crossLink?.storageMode,
                    let link = iFavorite.zoneLink,
                    link    != gTrashLink,
                    !found.contains(mode) {
                    found.append(mode)
                }
            }

            if  let children = rootZone?.children {
                for (index, favorite) in children.enumerated() {
                    if  let link  = favorite.zoneLink,
                        link     == gTrashLink {
                        if  foundTrash {
                            trashCopies.append(index)
                        } else {
                            foundTrash = true
                        }
                    }
                }

                while let index = trashCopies.last {
                    trashCopies.removeLast()
                    rootZone?.children.remove(at: index)
                }
            }

            for favorite in defaultFavorites.children {
                if  let mode = favorite.crossLink?.storageMode,
                    (!found.contains(mode) || favorite.isTrash) {
                    rootZone?.add(favorite)
                    favorite.clearAllStates() // erase side-effect of add
                }
            }

            if !foundTrash && gTrash != nil {
                let      trash = createBookmark(for: gTrash!, style: .addFavorite)
                trash.zoneLink = gTrashLink
                trash   .order = 0.999

                trash.clearAllStates()
                trash.needSave()
            }

            updateCurrentFavorite()
        }
    }


    var hereSpawnedCurrentFavorite: Bool {
        if  let target = currentFavorite?.bookmarkTarget, currentFavorite != nil {
            return gHere.spawned(target)
        }

        return false
    }


    func updateCurrentFavorite() {
        if  let    favorite = favorite(for: gHere),
            let      target = favorite.bookmarkTarget,
            (!hereSpawnedCurrentFavorite || gHere == target) {
            currentFavorite = favorite
        }
    }


    // MARK:- switch
    // MARK:-


    func nextFavoritesIndex(forward: Bool) -> Int {
        return next(favoritesIndex, forward)
    }


    func next(_ index: Int, _ forward: Bool) -> Int {
        let increment = (forward ? 1 : -1)
        var      next = index + increment
        let     count = rootZone!.count

        if next >= count {
            next =       0
        } else if next < 0 {
            next = count - 1
        }

        return next
    }


    func switchToNext(_ forward: Bool, atArrival: @escaping Closure) {
        let    index = nextFavoritesIndex(forward: forward)
        var     bump : IntClosure?
        bump         = { (iIndex: Int) in
            let zone = self.zoneAtIndex(iIndex)

            if !self.focus(on: zone, atArrival) {
                bump?(self.next(iIndex, forward))
            }
        }

        bump?(index)
    }


    @discardableResult func refocus(_ atArrival: @escaping Closure) -> Bool {
        if  let favorite = currentFavorite {
            return focus(on: favorite, atArrival)
        }

        return false
    }


    @discardableResult func focus(on iFavorite: Zone?, _ atArrival: @escaping Closure) -> Bool {
        if  let bookmark = iFavorite, bookmark.isBookmark {
            if  bookmark.isInFavorites {
                currentFavorite = bookmark

                gTravelManager.travelThrough(bookmark) { (iObject: Any?, iKind: ZSignalKind) in
                    atArrival()
                }

                return true
            } else if let mode = bookmark.crossLink?.storageMode {
                gStorageMode = mode

                gTravelManager.travel {
                    gHere.grab()
                    atArrival()
                }

                return true
            }

            performance("oops!")
        }

        return false
    }


    // MARK:- create
    // MARK:-


    @discardableResult func create(withBookmark: Zone?, _ name: String?) -> Zone {
        let bookmark: Zone = withBookmark ?? Zone(storageMode: .mineMode)
        bookmark.zoneName  = name

        return bookmark
    }


    @discardableResult func create(withBookmark: Zone?, _ style: ZFavoriteStyle, parent: Zone, atIndex: Int, _ name: String?) -> Zone {
        let bookmark: Zone = create(withBookmark: withBookmark, name)
        let insertAt: Int? = atIndex == parent.count ? nil : atIndex

        if style != .favorite {
            parent.add(bookmark, at: insertAt) // calls update progeny count
        }
        
        bookmark.updateRecordProperties() // is this needed?

        return bookmark
    }


    @discardableResult func createBookmark(for iZone: Zone, style: ZFavoriteStyle) -> Zone {
        var parent: Zone = iZone.parentZone ?? rootZone!
        let     isNormal = style == .normal

        if  !isNormal {
            let basis: ZRecord = !iZone.isBookmark ? iZone : iZone.crossLink!

            if  let recordName = basis.record?.recordID.recordName {
                parent         = rootZone!

                for bookmark in rootZone!.children {
                    if recordName == bookmark.crossLink?.record.recordID.recordName, !defaultFavorites.children.contains(bookmark) {
                        currentFavorite = bookmark

                        return bookmark
                    }
                }
            }
        }

        let           count = parent.count
        var bookmark: Zone? = iZone.isBookmark ? iZone.deepCopy() : nil
        var           index = parent.children.index(of: iZone) ?? count

        if style == .addFavorite {
            index           = nextFavoritesIndex(forward: gInsertionsFollow)
        }

        bookmark            = create(withBookmark: bookmark, style, parent: parent, atIndex: index, iZone.zoneName)

        bookmark?.needSave()

        if  isNormal {
            parent.maybeNeedMerge()
            parent.updateRecordProperties()
        }

        if !iZone.isBookmark {
            bookmark?.crossLink = iZone
        }

        return bookmark!
    }


    // MARK:- toggle
    // MARK:-


    func isChildOfFavoritesRoot(_ zone: Zone) -> Bool {
        var found = false

        if let recordName = zone.record?.recordID.recordName {
            rootZone?.traverseProgeny { iChild -> (ZTraverseStatus) in
                if  recordName == iChild.crossLink?.record.recordID.recordName, !defaultFavorites.children.contains(iChild) {
                    found = true

                    return .eStop
                }

                return .eContinue
            }
        }

        return found
    }


    func toggleFavorite(for zone: Zone) {
        if gHasPrivateDatabase && !zone.isRoot {
            if isChildOfFavoritesRoot(zone) {
                deleteFavorite(for:   zone)
            } else {
                createBookmark(for: zone, style: .addFavorite)
            }

            updateChildren()
        }
    }


    func deleteFavorite(for zone: Zone) {
        let recordID = zone.record.recordID

        for (index, favorite) in rootZone!.children.enumerated() {
            if  favorite.crossLink?.record.recordID == recordID {
                favorite.needDestroy()

                rootZone?.children.remove(at: index)

                break
            }
        }
    }
}
