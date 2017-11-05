//
//  ZOnboardingManager.swift
//  iFocus
//
//  Created by Jonathan Sand on 10/26/17.
//  Copyright © 2017 Zones. All rights reserved.
//


import Foundation
import CloudKit

#if os(OSX)
    import Cocoa
#elseif os(iOS)
    import UIKit
#endif


let gOnboardingManager = ZOnboardingManager()


class ZOnboardingManager : ZOperationsManager {


    var            user : ZUser?
    var    userIdentity : CKUserIdentity?
    var   isSpecialUser : Bool { return user?.access == .eAccessFull }
    let makeUserSpecial = false


    // MARK:- API
    // MARK:-


    func userHasAccess(_ zone: Zone) -> Bool {
        return isSpecialUser || zone.ownerID == nil || zone.ownerID!.recordName == gUserRecordID
    }


    func onboard(_ onCompletion: AnyClosure?) {
        setupAndRunOps(from: .setup, to: .fetchUserIdentity) { onCompletion?(0) }
    }


    // MARK:- internals
    // MARK:-


    override func performBlock(on operationID: ZOperationID, with logic: ZRecursionLogic? = nil, restoreToMode: ZStorageMode, _ onCompletion: @escaping Closure) {
        let done = {
            self.queue.isSuspended = false

            onCompletion()
        }

        switch operationID {
        case .setup:             setup();            done()
        case .internet:          internet          { done() }
        case .ubiquity:          ubiquity          { done() }
        case .accountStatus:     accountStatus     { done() }
        case .fetchUserID:       fetchUserID       { done() }
        case .fetchUserRecord:   fetchUserRecord   { done() }
        case .fetchUserIdentity: fetchUserIdentity { done() }
        default:                                     done()
        }
    }


    func cloudStateChanged(_ notification: Notification) {
        setupAndRunOps(from: .internet, to: .fetchUserIdentity) {}
    }


    func openSystemPreferences() {
        #if os(OSX)
            if let url = URL(string: "x-apple.systempreferences:com.apple.ids.service.com.apple.private.alloy.icloudpairing") {
                NSWorkspace.shared().open(url)
            }
        #else
            if let url = URL(string: "App-Prefs:root=General&path=Network") {
                UIApplication.shared.open(url)
            }
        #endif
    }


    // MARK:- operations
    // MARK:-


    func setup() {
        NotificationCenter.default.addObserver(self, selector: #selector(ZOnboardingManager.cloudStateChanged), name: .NSUbiquityIdentityDidChange, object: nil)
    }


    func internet(_ onCompletion: @escaping Closure) {
        onCompletion()
    }


    func ubiquity(_ onCompletion: @escaping Closure) {
        if FileManager.default.ubiquityIdentityToken == nil {
            gAlertManager.alert("To gain full use of this app,", "Please enable iCloud and turn on your iCloud drive", "Click here to open System Preferences") { iAlert in
                iAlert?.runModal()
                self.openSystemPreferences()
                onCompletion()
            }
        } else {
            onCompletion()
        }
    }


    func accountStatus(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            self.FOREGROUND {
                switch iStatus {
                case .available:
                    onCompletion()
                default:
                    // alert system prefs
                    break
                }
            }
        }
    }


    func fetchUserRecord(_ onCompletion: @escaping Closure) {
        if  let recordName = gUserRecordID {
            let ckRecordID = CKRecordID(recordName: recordName)

            gCloudManager.assureRecordExists(withRecordID: ckRecordID, recordType: CKRecordTypeUserRecord) { (iUserRecord: CKRecord?) in
                if  let  record = iUserRecord {
                    let    user = ZUser(record: record, storageMode: gStorageMode)
                    self  .user = user

                    if  self.makeUserSpecial {
                        user.access = .eAccessFull

                        user.needFlush()
                    }

                    onCompletion()
                } else {
                    // alert ... i forgot what caused this
                }
            }
        }
    }


    func fetchUserID(_ onCompletion: @escaping Closure) {
        gContainer.fetchUserRecordID() { iRecordID, iError in
            gAlertManager.alertError(iError, "failed to fetch user record id; reason unknown") { iHasError in
                if !iHasError {
                    gUserRecordID = iRecordID?.recordName

                    onCompletion()
                }
            }
        }
    }


    func fetchUserIdentity(_ onCompletion: @escaping Closure) {
        if  let recordName = gUserRecordID {
            let ckRecordID = CKRecordID(recordName: recordName)
            let  debugAuth = false

            gContainer.discoverUserIdentity(withUserRecordID: ckRecordID) { (iCKUserIdentity, iError) in
                let message = "failed to fetch user id; reason unknown"

                if  iError != nil {
                    gAlertManager.alertError(iError, message)
                    self.openSystemPreferences()
                } else if iCKUserIdentity != nil {
                    self.userIdentity = iCKUserIdentity
                } else if debugAuth {
                    gAlertManager.alert("To gain full use of this app,", "Please enable iCloud and turn on your iCloud drive", "Click here to open System Preferences") { iAlert in
                        iAlert?.runModal()
                        self.openSystemPreferences()
                    }
                }

                onCompletion()
            }
        }
    }


//    func status() {
//        [[CKContainer defaultContainer] accountStatusWithCompletionHandler:^(CKAccountStatus accountStatus, NSError *error) {
//            if (accountStatus == CKAccountStatusNoAccount) {
//            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Sign in to iCloud"
//            message:@"Sign in to your iCloud account to write records. On the Home screen, launch Settings, tap iCloud, and enter your Apple ID. Turn iCloud Drive on. If you don't have an iCloud account, tap Create a new Apple ID."
//            preferredStyle:UIAlertControllerStyleAlert];
//            [alert addAction:[UIAlertAction actionWithTitle:@"Okay"
//            style:UIAlertActionStyleCancel
//            handler:nil]];
//            [self presentViewController:alert animated:YES completion:nil];
//            }
//            else {
//            // Insert your just-in-time schema code here
//            }
//            }]
//
//    }

}
