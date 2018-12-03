//
//  ZControllersManager.swift
//  Zones
//
//  Created by Jonathan Sand on 11/11/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//

import Foundation


enum ZControllerID: Int {
    case undefined
    case searchResults
    case authenticate
    case information
    case preferences
    case favorites
    case shortcuts
    case details
    case actions
    case editor
    case search
    case debug
    case tools
    case help
    case main
}


enum ZSignalKind: Int {
    case data
    case main
    case datum
    case debug
    case error
    case found
    case search
    case startup
    case details
    case relayout
    case appearance
    case information
    case preferences
}


let gControllersManager = ZControllersManager()


class ZControllersManager: NSObject {


    var currentController: ZGenericController?
    var signalObjectsByControllerID = [ZControllerID : ZSignalObject] ()


    class ZSignalObject {
        let    closure: SignalClosure!
        let controller: ZGenericController!

        init(_ iClosure: @escaping SignalClosure, forController iController: ZGenericController) {
            controller = iController
            closure    = iClosure
        }
    }


    func controllerForID(_ iID: ZControllerID?) -> ZGenericController? {
        if  let identifier = iID,
            let     object = signalObjectsByControllerID[identifier] {
            return object.controller
        }

        return nil
    }


    // MARK:- startup
    // MARK:-


    func startupCloudAndUI() {
        gBatchManager.usingDebugTimer = true

        gRemoteStoresManager.clear()
        self.signalFor(nil, regarding: .relayout)

        gBatchManager.startUp { iSame in
            FOREGROUND {
                gWorkMode        = .graphMode
                gIsReadyToShowUI = true

                gHere.grab()
                gFavoritesManager.updateFavorites()
                gRemoteStoresManager.updateLastSyncDates()
                gRemoteStoresManager.recount()
                self.signalFor(nil, regarding: .relayout)
                self.requestFeedback()
                
                gBatchManager.finishUp { iSame in
                    FOREGROUND {
                        gBatchManager.usingDebugTimer = false

                        self.blankScreenDebug()
                        self.signalFor(nil, regarding: .relayout)
                        gRemoteStoresManager.saveAll()
                    }
                }
            }
        }
    }

    
    func requestFeedback() {
        if       !emailSent(for: .eBetaTesting) {
            recordEmailSent(for: .eBetaTesting)

            FOREGROUND(after: 0.1) {
                let image = ZImage(named: kHelpMenuImageName)
                
                gAlertManager.showAlert("Please forgive my interruption",
                                        "Thank you for downloading Thoughtful. You are one of my first customers. \n\nMy other product (no longer available) received 99% positive customer satisfaction. Receiving the same for Thoughtful would mean a lot to me, of course. I built Thoughtful alone so far, but it's getting hefty. Might you be interested in helping me beta test Thoughtful, giving me feedback about it (good and bad)? \n\nYou can let me know at any time, by selecting Report an Issue under the Help menu (red arrow), or now, by clicking the Reply button below.",
                                        "Reply in an email",
                                        "Dismiss",
                                        image) { iObject in
                                            if  iObject != .eStatusNo {
                                                self.sendEmailBugReport()
                                            }
                }
            }
        }
    }
    

    // MARK:- registry
    // MARK:-


    func register(_ iController: ZGenericController, iID: ZControllerID, closure: @escaping SignalClosure) {
        signalObjectsByControllerID[iID] = ZSignalObject(closure, forController: iController)
        currentController                = iController
    }


    func unregister(_ at: ZControllerID) {
        signalObjectsByControllerID[at] = nil
    }


    // MARK:- signals
    // MARK:-


    func displayActivity(_ show: Bool) {
        FOREGROUND {
            for signalObject in self.signalObjectsByControllerID.values {
                signalObject.controller.displayActivity(show)
            }
        }
    }


    func updateNeededCounts() {
        for dbID in kAllDatabaseIDs {
            var alsoProgenyCounts = false
            let           manager = gRemoteStoresManager.cloudManager(for: dbID)
            manager?.fullUpdate(for: [.needsCount]) { state, iZRecord in
                if  let zone                 = iZRecord as? Zone {
                    if  zone.fetchableCount != zone.count {
                        zone.fetchableCount  = zone.count
                        alsoProgenyCounts    = true

                        zone.maybeNeedSave()
                    }
                }
            }

            if  alsoProgenyCounts {
                manager?.rootZone?.updateCounts()
            }
        }
    }


    func signalFor(_ object: Any?, regarding: ZSignalKind, onCompletion: Closure? = nil) {
        FOREGROUND(canBeDirect: true) {
            self.updateNeededCounts() // clean up after adding or removing children
            
            for (identifier, signalObject) in self.signalObjectsByControllerID {
                let isInformation = identifier == .information
                let isPreferences = identifier == .preferences
                let       isDebug = identifier == .debug
                let        isMain = identifier == .main
                let      isDetail = isInformation || isPreferences || isDebug
                
                let closure = {
                    signalObject.closure(object, regarding)                    
                }

                switch regarding {
                case .main:        if isMain        { closure() }
                case .debug:       if isDebug       { closure() }
                case .details:     if isDetail      { closure() }
                case .information: if isInformation { closure() }
                case .preferences: if isPreferences { closure() }
                default:                              closure()
                }
            }

            onCompletion?()
        }
    }


    func syncToCloudAfterSignalFor(_ zone: Zone?, regarding: ZSignalKind,  onCompletion: Closure?) {
        signalFor(zone, regarding: regarding, onCompletion: onCompletion)
        gBatchManager.sync { iSame in
            onCompletion?()
        }
    }
}
