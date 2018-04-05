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


var gIsSpecialUser: Bool { return gBatchManager.isSpecialUser }


class ZOnboardingManager : ZOperationsManager {


    var            user : ZUser?
    var   isSpecialUser : Bool { return user?.access == .eAccessFull }
    let makeUserSpecial = false


    // MARK:- internals
    // MARK:-


    func completeOnboarding(_ notification: Notification) {
        FOREGROUND(canBeDirect: true) {
            self.setupAndRun([.fetchUserRecord]) {}
        }
    }


    // MARK:- operations
    // MARK:-


    override func ivokeMultiple(for operationID: ZOperationID, restoreToID: ZDatabaseID, _ onCompletion: @escaping BooleanClosure) {
        switch operationID {
        case .observeUbiquity:  observeUbiquity();  onCompletion(true)      // true means op is handled
        case .accountStatus:    accountStatus     { onCompletion(true) }
        case .fetchUserID:      fetchUserID       { onCompletion(true) }
        case .internet:         internet          { onCompletion(true) }
        case .ubiquity:         ubiquity          { onCompletion(true) }
        case .fetchUserRecord:  fetchUserRecord   { onCompletion(true) }
        default:                                    onCompletion(false)     // false means op is not handled, so super should proceed
        }
    }


    func internet(_ onCompletion: @escaping Closure) {
        checkCloudStatus()
        onCompletion()
    }


    func observeUbiquity() {
        NotificationCenter.default.addObserver(self, selector: #selector(ZOnboardingManager.completeOnboarding), name: .NSUbiquityIdentityDidChange, object: nil)
    }


    func accountStatus(_ onCompletion: @escaping Closure) {
        gContainer.accountStatus { (iStatus, iError) in
            if  iStatus            == .available {
                gCloudAccountStatus = .available

                //////////////////////////
                // ONBOARDING CONTINUES //
                //////////////////////////
            }

            onCompletion()
        }
    }


    func fetchUserID(_ onCompletion: @escaping Closure) {
        if gCloudAccountStatus != .available {
            onCompletion()
        } else {
            gContainer.fetchUserRecordID() { iRecordID, iError in
                gAlertManager.alertError(iError, "failed to fetch user record id; reason unknown") { iHasError in
                    if !iHasError {

                        ////////////////////////////////////////////////
                        // persist for file read on subsequent launch //
                        //   also: for determining write permission   //
                        ////////////////////////////////////////////////

                        gUserRecordID = iRecordID?.recordName

                        //////////////////////////
                        // ONBOARDING CONTINUES //
                        //////////////////////////
                    }

                    onCompletion()
                }
            }
        }
    }


    func ubiquity(_ onCompletion: @escaping Closure) {
        if FileManager.default.ubiquityIdentityToken == nil {

            //////////////////////////
            // ONBOARDING CONTINUES //
            //////////////////////////

            checkCloudStatus()
        }

        onCompletion()
    }


    func fetchUserRecord(_ onCompletion: @escaping Closure) {
        if gCloudAccountStatus == .available,
            let     recordName  = gUserRecordID {
            let     ckRecordID  = CKRecordID(recordName: recordName)

            gCloudManager.assureRecordExists(withRecordID: ckRecordID, recordType: CKRecordTypeUserRecord) { (iUserRecord: CKRecord?) in
                if  let          record = iUserRecord {
                    let            user = ZUser(record: record, databaseID: gDatabaseID)
                    self          .user = user
                    gCloudAccountStatus = .active

                    //////////////////////////
                    // ONBOARDING CONTINUES //
                    //////////////////////////

                    if  self.makeUserSpecial {
                        user.access = .eAccessFull

                        user.maybeNeedSave()
                    }
                } else {
                    let            name = ckRecordID.recordName
                    gCloudAccountStatus = .none

                    ////////////////////////
                    //  ONBOARDING STOPS  //
                    ////////////////////////

                    // see: shouldPerform

                    print("alert: user record \(name) does not exist")
                }

                onCompletion()
            }
        } else {
            onCompletion()
        }
    }

}
