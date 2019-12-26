//
//  ZEnumerations.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 1/31/18.
//  Copyright © 2018 Jonathan Sand. All rights reserved.
//


import Foundation
import CloudKit


enum InterfaceStyle : String {
    case Dark, Light
    
    init() {
        let type = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"

        self = InterfaceStyle(rawValue: type)!
    }
}


enum ZRootID: String {
    case graph     = "root"
    case trash     = "trash"
    case destroy   = "destroy"
    case favorites = "favorites"
    case lost      = "lost and found"
}


enum ZCloudAccountStatus: Int {
    case none
    case begin
    case available
    case active
}


enum ZInsertionMode: Int {
    case precede
    case follow
}


enum ZBrowsingMode: Int {
    case confined
    case cousinJumps
}


enum ZFileMode: Int {
    case localOnly
    case cloudOnly
    case all
}


enum ZWorkMode: Int {
    case noRedrawMode
    case startupMode
    case searchMode
    case graphMode
	case essayMode
    // case outlineMode
}


enum ZCountsMode: Int { // do not change the order, they are persisted
    case none
    case dots
    case fetchable
    case progeny
}


enum ZOutlineLevelType: String {
    case capital = "A"
    case  number = "1"
    case   small = "a"
    case   roman = "i"

    var asciiValue: UInt32 { return rawValue.asciiValue }
    var level: Int {
		switch self {
			case .capital: return 0
			case .number:  return 1
			case .small:   return 2
			case .roman:   return 3
		}
    }
}


enum ZDatabaseID: String {
	case preferencesID = "preferences"
    case   favoritesID = "favorites"
    case    everyoneID = "everyone"
    case      sharedID = "shared"
    case        mineID = "mine"
	
	var identifier: String { return rawValue.substring(toExclusive: 1) }
	var index:        Int? { return self.databaseIndex?.rawValue }

    var userReadableString: String {
		switch self {
			case .everyoneID: return "public"
			case     .mineID: return "my"
			default:          return ""
		}
    }
	
    
    var databaseIndex: ZDatabaseIndex? {
		switch self {
			case .favoritesID: return .favoritesIndex
			case  .everyoneID: return .everyoneIndex
			case      .mineID: return .mineIndex
			default:           return nil
		}
    }

    static func convert(from scope: CKDatabase.Scope) -> ZDatabaseID? {
		switch scope {
			case .public:  return .everyoneID
			case .private: return .mineID
			default:       return nil
		}
    }

    static func convert(from id: String) -> ZDatabaseID? {
		switch id {
			case "e": return .everyoneID
			case "m": return .mineID
			default:  return nil
		}
    }
    
    func isDeleted(dict: ZStorageDictionary) -> Bool {
        let    name = dict[.recordName] as? String
        
        return name == nil ? false : gRemoteStorage.cloud(for: self)?.manifest?.deleted?.contains(name!) ?? false
    }
    
}


enum ZDatabaseIndex: Int {
	case everyoneIndex
    case mineIndex
	case favoritesIndex

    
    var databaseID: ZDatabaseID? {
		switch self {
			case .favoritesIndex: return .favoritesID
			case .everyoneIndex:  return .everyoneID
			case .mineIndex:      return .mineID
		}
    }
}


struct ZDetailsViewID: OptionSet {
    let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }

    static let Information = ZDetailsViewID(rawValue: 0x0001)
    static let Preferences = ZDetailsViewID(rawValue: 0x0002)
    static let       Tools = ZDetailsViewID(rawValue: 0x0008)
    static let       Debug = ZDetailsViewID(rawValue: 0x0010)
    static let         All = ZDetailsViewID(rawValue: 0x001F)
}


enum ZStorageType: String {
    case lost            = "lostAndFound"    // general
    case bookmarks       = "bookmarks"
    case favorites       = "favorites"
    case manifest        = "manifest"
    case destroy         = "destroy"
    case userID          = "user ID"
    case model           = "model"
    case graph           = "graph"
    case trash           = "trash"
    case date            = "date"

	case essayAttributes = "essayAttributes" // zones
    case recordName      = "recordName"
    case parentLink      = "parentLink"
    case attributes      = "attributes"
    case children        = "children"
    case progeny         = "progeny"
    case traits          = "traits"
    case access          = "access"
    case author          = "author"
	case essay           = "essay"
	case order           = "order"
    case color           = "color"
    case count           = "count"
    case needs           = "needs"
    case link            = "link"
    case name            = "name"

	case format          = "format"          // traits
	case asset           = "asset"
    case time            = "time"
    case text            = "text"
    case data            = "data"
    case type            = "type"

    case deleted         = "deleted"         // ZManifest
}

// MARK: - debug
// MARK: -

struct ZDebugMode: OptionSet, CustomStringConvertible {
	static var structValue = 1
	static var nextValue: Int { structValue *= 2; return structValue }
	let rawValue: Int

	init() { rawValue = ZDebugMode.nextValue }
	init(rawValue: Int) { self.rawValue = rawValue }

	static let      none = ZDebugMode(rawValue: 0)
	static let       log = ZDebugMode(rawValue: 1)
	static let     error = ZDebugMode()
	static let     essay = ZDebugMode()

	var description: String {
		return [(.log,       "    log"),
				(.error,     "  error"),
				(.essay,     "  essay")]
			.compactMap { (option, name) in contains(option) ? name : nil }
			.joined(separator: " ")
	}
}
