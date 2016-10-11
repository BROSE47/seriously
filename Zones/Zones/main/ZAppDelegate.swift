//
//  ZAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Zones. All rights reserved.
//


import Cocoa
import CloudKit


@NSApplicationMain


class ZAppDelegate: NSResponder, ZApplicationDelegate {


    func applicationDidFinishLaunching(aNotification: NSNotification) {
    }


    func applicationDidBecomeActive(_ notification: Notification) {
        modelManager.resetBadgeCounter()
        zapplication.registerForRemoteNotifications(matching: .badge)
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo as! [String : NSObject])

        if note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            modelManager.receivedUpdateFor(queryNote.recordID!)
        }
    }


    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
        persistenceManager.save()
        
        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplicationTerminateReply {
        return .terminateNow
    }
}

