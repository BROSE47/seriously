//
//  ZState.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 10/14/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation
import CloudKit

#if os(OSX)
import Cocoa
let gFontDelta = 15.0
let gDotFactor = CGFloat(2.5)
var gTextOffset: CGFloat?
#elseif os(iOS)
import UIKit
let gFontDelta = 17.0
let gDotFactor = CGFloat(1.25)
var gTextOffset: CGFloat? { return gTextEditor.currentOffset }
#endif

var              gDeferRedraw                     = false
var            gTextCapturing                     = false
var          gIsReadyToShowUI                     = false
var        gKeyboardIsVisible                     = false
var        gArrowsDoNotBrowse                     = false
var       gHasFinishedStartup                     = false
var      gCreateCombinedEssay 			   		  = false
var    gRefusesFirstResponder                     = false
var   gIsEditingStateChanging                     = false
var    gTimeUntilCurrentEvent:       TimeInterval = 0  // by definition, first event is startup
var gCurrentMouseDownLocation:           CGFloat?
var     gCurrentMouseDownZone:              Zone?
var       gCurrentBrowseLevel:               Int?
var        gCurrentKeyPressed:            String?
var          gDragDropIndices: NSMutableIndexSet?
var             gDragRelation:         ZRelation?
var             gDragDropZone:              Zone?
var              gDraggedZone:              Zone?
var                gDragPoint:           CGPoint?
var                 gExpanded:          [String]?

var                 gDarkMode:     InterfaceStyle { return InterfaceStyle() }
var                   gIsDark:               Bool { return gDarkMode == .Dark }
var                   gIsLate:               Bool { return gBatches.isLate }
var               gIsDragging:               Bool { return gDraggedZone != nil }
var     gIsShortcutsFrontmost:               Bool { return gShortcuts?.view.window?.isKeyWindow ?? false }
var       gBrowsingIsConfined:               Bool { return gBrowsingMode == .confined }
var            gListsGrowDown:               Bool { return gListGrowthMode == .down }
var           gDuplicateEvent:               Bool { return gCurrentEvent != nil && (gTimeSinceCurrentEvent < 0.4) }
var               gIsNoteMode:               Bool { return gWorkMode == .noteMode }
var              gIsGraphMode:               Bool { return gWorkMode == .graphMode }
var             gIsSearchMode:               Bool { return gWorkMode == .searchMode }
var           gIsEditIdeaMode:               Bool { return gWorkMode == .editIdeaMode }
var          gCanSaveWorkMode:               Bool { return gIsGraphMode || gIsNoteMode }
var    gIsGraphOrEditIdeaMode:               Bool { return gIsGraphMode || gIsEditIdeaMode }
var    gTimeSinceCurrentEvent:       TimeInterval { return Date.timeIntervalSinceReferenceDate - gTimeUntilCurrentEvent }
var                 gDragView:         ZDragView? { return gGraphController?.dragView }
var                gDotHeight:             Double { return Double(gGenericOffset.height / gDotFactor) + 13.0 }
var                 gDotWidth:             Double { return gDotHeight * 0.75 }
var       gChildrenViewOffset:             Double { return gDotWidth + Double(gGenericOffset.height) * 1.2 }
var                 gFontSize:            CGFloat { return gGenericOffset.height + CGFloat(gFontDelta) } // height 2 .. 20
var               gWidgetFont:              ZFont { return .systemFont(ofSize: gFontSize) }
var            gFavoritesFont:              ZFont { return .systemFont(ofSize: gFontSize * kFavoritesReduction) }
var         gDefaultTextColor:             ZColor { return (gIsDark && !gIsPrinting) ? kWhiteColor : ZColor.black }
var         gNecklaceDotColor:             ZColor { return gBackgroundColor.darker  (by: 1.3)   }
var    gDarkerBackgroundColor:             ZColor { return gBackgroundColor.darker  (by: 4.0)   }
var   gDarkishBackgroundColor:             ZColor { return gBackgroundColor.darkish (by: 1.028) }
var  gLightishBackgroundColor:             ZColor { return gBackgroundColor.lightish(by: 1.02)  }
var   gLighterBackgroundColor:             ZColor { return gBackgroundColor.lighter (by: 4.0)   }
var   gLighterRubberbandColor:             ZColor { return gRubberbandColor.lighter (by: 4.0)   }
var   gNecklaceSelectionColor:             ZColor { return gNecklaceDotColor + gLighterRubberbandColor }
var         gDefaultEssayFont:              ZFont { return ZFont(name: "Times-Roman",            size: gEssayTextFontSize)  ?? ZFont.systemFont(ofSize: gEssayTextFontSize) }
var           gEssayTitleFont:              ZFont { return ZFont(name: "TimesNewRomanPS-BoldMT", size: gEssayTitleFontSize) ?? ZFont.systemFont(ofSize: gEssayTitleFontSize) }
var	 			   gBlankLine: NSAttributedString { return NSMutableAttributedString(string: "\n", attributes: [.font : gEssayTitleFont]) }
func         gSetEditIdeaMode()                   { gWorkMode = .editIdeaMode }
func            gSetGraphMode()                   { gWorkMode = .graphMode }

var gCurrentEvent: ZEvent? {
	didSet {
		gTimeUntilCurrentEvent = Date.timeIntervalSinceReferenceDate
	}
}

var gExpandedZones : [String] {
    get {
        if  gExpanded == nil {
            let  value = getPreferencesString(for: kExpandedZones, defaultString: "")
            gExpanded  = value?.components(separatedBy: kSeparator)
        }

        return gExpanded!
    }

    set {
        gExpanded = newValue

        setPreferencesString(newValue.joined(separator: kSeparator), for: kExpandedZones)
    }
}

var gHere: Zone {
	get {
		return gRecords!.hereZone
	}

	set {
		if  let    dbID = newValue.databaseID {
			gDatabaseID = dbID
		}

		gRecords?.hereZone = newValue

		gFocusRing.push()
	}
}

var gRecords: ZRecords? {
	get { return gShowFavorites ? gFavorites : gCloud }
}

var gHereMaybe: Zone? {
    get { return gRecords?.hereZoneMaybe }
    set { gRecords?.hereZoneMaybe = newValue }
}

var gClipBreadcrumbs : Bool {
	get { return getPreferencesBool(   for: kClipBreadcrumbs, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kClipBreadcrumbs) }
}

var gShowAllBreadcrumbs : Bool {
	get { return getPreferencesBool(   for: kShowAllBreadcrumbs, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowAllBreadcrumbs) }
}

var gToolTipsAlwaysVisible : Bool {
	get { return getPreferencesBool(   for: kToolTipsAlwaysVisible, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kToolTipsAlwaysVisible) }
}

var gShowFavorites : Bool {
	get { return getPreferencesBool(   for: kShowFavorites, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kShowFavorites) }
}

var gMathewStyleUI : Bool {
    get { return getPreferencesBool(   for: kMathewStyle, defaultBool: false) }
    set { setPreferencesBool(newValue, for: kMathewStyle) }
}

var gHereRecordNames: String {
    get { return getPreferenceString(    for: kHereRecordIDs) { return kRootName + kSeparator + kRootName }! }
    set { setPreferencesString(newValue, for: kHereRecordIDs) }
}

var gAuthorID: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kAuthorID) { return nil } }
    set { setPreferencesString(newValue, for: kAuthorID) }
}

var gUserRecordID: String? {    // persist for file read on launch
    get { return getPreferenceString(    for: kUserRecordID) }
    set { setPreferencesString(newValue, for: kUserRecordID) }
}

var gEmailTypesSent: String {
    get {
        let pref = getPreferenceString(for: kEmailTypesSent) ?? ""
        let sent = gUser?.sentEmailType ?? pref
        
        setPreferencesString(sent, for: kEmailTypesSent)
        gUser?.sentEmailType = sent
        
        return sent
    }
    
    set {
        setPreferencesString(newValue, for: kEmailTypesSent)
        gUser?.sentEmailType = newValue
    }
}

var gFullRingIsVisible: Bool {
	get { return getPreferencesBool(   for: kFullRingIsVisible, defaultBool: true) }
	set { setPreferencesBool(newValue, for: kFullRingIsVisible) }
}

var gFavoritesAreVisible: Bool {
	get { return getPreferencesBool(   for: kFavoritesAreVisibleKey, defaultBool: false) }
	set { setPreferencesBool(newValue, for: kFavoritesAreVisibleKey) }
}

var gBackgroundColor: ZColor {
	get { return   getPreferencesColor( for: kBackgroundColorKey, defaultColor: ZColor(red: 241.0/256.0, green: 227.0/256.0, blue: 206.0/256.0, alpha: 1.0)) } //0.99 / 360.0, saturation: 0.13, brightness: kUnselectBrightness, alpha: 1)) }
	set { setPreferencesColor(newValue, for: kBackgroundColorKey) }
}

var gRubberbandColor: ZColor {
	get { return   getPreferencesColor( for: kRubberbandColorKey, defaultColor: ZColor.purple.darker(by: 1.5)) }
	set { setPreferencesColor(newValue, for: kRubberbandColorKey) }
}

var gGenericOffset: CGSize {
	get {
		var offset = getPreferencesSize(for: kGenericOffsetKey, defaultSize: CGSize(width: 30.0, height: 2.0))
		
		if  kIsPhone {
			offset.height += 5.0
		}
		
		return offset
	}
	set {
		setPreferencesSize(newValue, for: kGenericOffsetKey)
	}
}

var gWindowRect: CGRect {
	get { return getPreferencesRect(for: kWindowRectKey, defaultRect: kDefaultWindowRect) }
	set { setPreferencesRect(newValue, for: kWindowRectKey) }
}

let gEssayTextFontSize = kDefaultEssayTextFontSize
let gEssayTitleFontSize = kDefaultEssayTitleFontSize
var gEssayTitleFontSizex: CGFloat {
	get { return getPreferencesAmount(for: kEssayTitleFontSize, defaultAmount: kDefaultEssayTitleFontSize) }
	set { setPreferencesAmount(newValue, for: kEssayTitleFontSize) }
}

var gScrollOffset: CGPoint {
	get {
		let  point = CGPoint(x: 0.0, y: 0.0)
		let string = getPreferenceString(for: kScrollOffsetKey) { return NSStringFromPoint(point) }
		
		return string?.cgPoint ?? point
	}
	
	set {
		let string = NSStringFromPoint(newValue)
		
		setPreferencesString(string, for: kScrollOffsetKey)
	}
}

var gBrowsingMode: ZBrowsingMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kBrowsingMode) as? Int
		var mode   = ZBrowsingMode.confined
		
		if  value != nil {
			mode   = ZBrowsingMode(rawValue: value!)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kBrowsingMode)
			UserDefaults.standard.synchronize()
		}
		
		return mode
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kBrowsingMode)
		UserDefaults.standard.synchronize()
	}
}

var gCountsMode: ZCountsMode {
	get {
		let value  = UserDefaults.standard.object(forKey: kCountsMode) as? Int
		var mode   = ZCountsMode.dots
		
		if  value != nil {
			mode   = ZCountsMode(rawValue: value!)!
		} else {
			UserDefaults.standard.set(mode.rawValue, forKey:kCountsMode)
			UserDefaults.standard.synchronize()
		}
		
		return mode
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kCountsMode)
		UserDefaults.standard.synchronize()
	}
}

var gScaling: Double {
	get {
		var value: Double? = UserDefaults.standard.object(forKey: kScaling) as? Double
		
		if value == nil {
			value = 1.00
			
			UserDefaults.standard.set(value, forKey:kScaling)
			UserDefaults.standard.synchronize()
		}
		
		return value!
	}
	
	set {
		UserDefaults.standard.set(newValue, forKey:kScaling)
		UserDefaults.standard.synchronize()
	}
}

var gLineThickness: Double {
	get {
		var value: Double? = UserDefaults.standard.object(forKey: kThickness) as? Double
		
		if  value == nil {
			value = 1.25
			
			UserDefaults.standard.set(value, forKey:kThickness)
			UserDefaults.standard.synchronize()
		}
		
		return value!
	}
	
	set {
		UserDefaults.standard.set(newValue, forKey:kThickness)
		UserDefaults.standard.synchronize()
	}
}

var gListGrowthMode: ZListGrowthMode {
	get {
		var mode: ZListGrowthMode?
		
		if let object = UserDefaults.standard.object(forKey:kInsertionMode) {
			mode      = ZListGrowthMode(rawValue: object as! Int)
		}
		
		if  mode == nil {
			mode      = .down
			
			UserDefaults.standard.set(mode!.rawValue, forKey:kInsertionMode)
			UserDefaults.standard.synchronize()
		}
		
		return mode!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kInsertionMode)
		UserDefaults.standard.synchronize()
	}
}

var gDatabaseID: ZDatabaseID {
	get {
		var dbID: ZDatabaseID?
		
		if let object = UserDefaults.standard.object(forKey:kDatabaseID) {
			dbID      = ZDatabaseID(rawValue: object as! String)
		}
		
		if  dbID     == nil {
			dbID      = .everyoneID
			
			UserDefaults.standard.set(dbID!.rawValue, forKey:kDatabaseID)
			UserDefaults.standard.synchronize()
		}
		
		return dbID!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kDatabaseID)
		UserDefaults.standard.synchronize()
	}
}

var gHiddenDetailViewIDs: ZDetailsViewID {
	get {
		var state: ZDetailsViewID?
		
		if let object = UserDefaults.standard.object(forKey:kDetailsState) {
			state     = ZDetailsViewID(rawValue: object as! Int)
		}
		
		if state == nil {
			state     = .All
			
			UserDefaults.standard.set(state!.rawValue, forKey:kDetailsState)
			UserDefaults.standard.synchronize()
		}
		
		return state!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kDetailsState)
		UserDefaults.standard.synchronize()
	}
}

#if os(iOS)
var gCurrentFunction : ZFunction {
	get {
		var function: ZFunction?
		
		if  let object = UserDefaults.standard.object(forKey:kActionFunction) {
			function   = ZFunction(rawValue: object as! String)
		}
		
		if  function  == nil {
			function   = .eTop
			
			UserDefaults.standard.set(function!.rawValue, forKey:kActionFunction)
			UserDefaults.standard.synchronize()
		}
		
		return function!
	}
	
	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kActionFunction)
		UserDefaults.standard.synchronize()
	}
}

var gCurrentGraph : ZFunction {
	get {
		var graph: ZFunction?
		
		if  let object = UserDefaults.standard.object(forKey:kCurrentGraph) {
			graph      = ZFunction(rawValue: object as! String)
		}
		
		if  graph     == nil {
			graph      = .eMe
			
			UserDefaults.standard.set(graph!.rawValue, forKey:kActionFunction)
			UserDefaults.standard.synchronize()
		}
		
		return graph!
	}

	set {
		UserDefaults.standard.set(newValue.rawValue, forKey:kCurrentGraph)
		UserDefaults.standard.synchronize()
	}
}

#endif

var gWorkMode: ZWorkMode = .startupMode {
	didSet {
		if  gCanSaveWorkMode {
			setPreferencesInt(gWorkMode.rawValue, for: kWorkMode)
		}

		if  gIsGraphOrEditIdeaMode {
			printDebug(.edit, "[m]       \(gIsEditIdeaMode ? "idea " : "graph")")
		}
	}
}

var gCurrentEssay: ZNote? {
	didSet {
		gEssayRing.push()
		setPreferencesString(gCurrentEssay?.identifier() ?? "", for: kCurrentEssay)
	}
}

// MARK:- actions
// MARK:-

var mouseLocationTimer: Timer?

func gTemporarilySetMouseDownLocation(_ location: CGFloat?, for seconds: Double = 1.0) {
	if  let t                     = mouseLocationTimer {
		t.invalidate()
	}

	printDebug(.edit, "[locate]  \(location?.description ?? "nil")")
	gCurrentMouseDownLocation     = location
	mouseLocationTimer            = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { iTimer in
		gCurrentMouseDownLocation = nil
	}
}

var mouseZoneTimer: Timer?

func gTemporarilySetMouseZone(_ zone: Zone?, for seconds: Double = 1.0) {
	if  let t                 = mouseZoneTimer {
		t.invalidate()
	}

	gCurrentMouseDownZone     = zone
	mouseZoneTimer            = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { iTimer in
		gCurrentMouseDownZone = nil
	}
}

func gTestForUserInterrupt() throws {
	if  let w = gWindow, (w.mouseMoved || w.keyPressed) {
		throw(ZInterruptionError.userInterrupted)
	}
}

func gRefreshCurrentEssay() {
	if  let identifier = getPreferencesString(for: kCurrentEssay, defaultString: nil),
		let      essay = gEssayRing.object(for: identifier) as? ZNote {
		gCurrentEssay  = essay
	}
}

func gRefreshPersistentWorkMode() {
	if  let     mode = getPreferencesInt(for: kWorkMode, defaultInt: ZWorkMode.startupMode.rawValue),
		let workMode = ZWorkMode(rawValue: mode) {
		gWorkMode    = workMode
	}
}

@discardableResult func toggleRingControlModes(isDirection: Bool) -> Bool {
	if isDirection {
		gListGrowthMode = gListsGrowDown      ? .up          : .down
	} else {
		gBrowsingMode   = gBrowsingIsConfined ? .cousinJumps : .confined
	}

	return true
}

func toggleDatabaseID() {
	switch        gDatabaseID {
	case .mineID: gDatabaseID = .everyoneID
	default:      gDatabaseID = .mineID
	}
}

func emailSent(for type: ZSentEmailType) -> Bool {
    return gEmailTypesSent.contains(type.rawValue)
}

func recordEmailSent(for type: ZSentEmailType) {
    if  !emailSent  (for: type) {
        gEmailTypesSent.append(type.rawValue)
    }
}

func key(for flag: Bool) -> String {
	return "\(flag ? "note" : "focus") \(kRingContents)"
}

func getRingContents(for flag: Bool) -> [String] {
	return getPreferenceString(for: key(for: flag)) { return nil }?.componentsSeparatedAt(level: 0) ?? []
}

func setRingContents(for flag: Bool, strings: [String]) {
	setPreferencesString(strings.joined(separator: gSeparatorAt(level: 0)), for: key(for: flag))
}

// MARK:- internals
// MARK:-

func getPreferencesAmount(for key: String, defaultAmount: CGFloat = 0.0) -> CGFloat {
	return getPreferenceString(for: key) { return "\(defaultAmount)" }?.floatValue ?? defaultAmount
}

func setPreferencesAmount(_ iAmount: CGFloat = 0.0, for key: String) {
	setPreferencesString("\(iAmount)", for: key)
}

func getPreferencesSize(for key: String, defaultSize: CGSize = CGSize.zero) -> CGSize {
    return getPreferenceString(for: key) { return NSStringFromSize(defaultSize) }?.cgSize ?? defaultSize
}

func setPreferencesSize(_ iSize: CGSize = CGSize.zero, for key: String) {
    setPreferencesString(NSStringFromSize(iSize), for: key)
}

func getPreferencesRect(for key: String, defaultRect: CGRect = CGRect.zero) -> CGRect {
    return getPreferenceString(for: key) { return NSStringFromRect(defaultRect) }?.cgRect ?? defaultRect
}

func setPreferencesRect(_ iRect: CGRect = CGRect.zero, for key: String) {
    setPreferencesString(NSStringFromRect(iRect), for: key)
}

func getPreferencesColor(for key: String, defaultColor: ZColor) -> ZColor {
    var color = defaultColor

    if  let data = UserDefaults.standard.object(forKey: key) as? Data,
		let    c = NSKeyedUnarchiver.unarchiveObject(with: data) as? ZColor {
        color    = c
    } else {
        setPreferencesColor(color, for: key)
    }
    
    if  gIsDark {
        color = color.inverted
    }

    return color
}

func setPreferencesColor(_ iColor: ZColor, for key: String) {
    var color = iColor
    
    if  gIsDark {
        color = color.inverted
    }

    let data: Data = NSKeyedArchiver.archivedData(withRootObject: color)

    UserDefaults.standard.set(data, forKey: key)
    UserDefaults.standard.synchronize()
}

func getPreferenceString(for key: String, needDefault: ToStringClosure? = nil) -> String? {
    if  let    string = UserDefaults.standard.object(forKey: key) as? String {
        return string
    }

    let defaultString = needDefault?()
    if  let    string = defaultString {
        setPreferencesString(string, for: key)
    }

    return defaultString
}

func getPreferencesString(for key: String, defaultString: String?) -> String? {
    return getPreferenceString(for: key) { return defaultString }
}

func setPreferencesString(_ iString: String?, for key: String) {
    if let string = iString {
        UserDefaults.standard.set(string, forKey: key)
        UserDefaults.standard.synchronize()
    }
}

func getPreferencesInt(for key: String, defaultInt: Int?) -> Int? {
	if  let         i = defaultInt,
		let    string = getPreferencesString(for: key, defaultString: "\(i)") {
		return string.integerValue
	}

	return defaultInt
}

func setPreferencesInt(_ iInt: Int?, for key: String) {
	if  let i = iInt {
		UserDefaults.standard.set("\(i)", forKey: key)
		UserDefaults.standard.synchronize()
	}
}

func getPreferencesBool(for key: String, defaultBool: Bool) -> Bool {
    if  let value: NSNumber = UserDefaults.standard.object(forKey: key) as? NSNumber {
        return value.boolValue
    }

    setPreferencesBool(defaultBool, for: key)

    return defaultBool
}

func setPreferencesBool(_ iBool: Bool, for key: String) {
    UserDefaults.standard.set(iBool, forKey: key)
    UserDefaults.standard.synchronize()
}
