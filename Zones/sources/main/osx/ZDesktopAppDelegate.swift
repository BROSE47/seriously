//
//  ZDesktopAppDelegate.swift
//  Zones
//
//  Created by Jonathan Sand on 7/2/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import Cocoa
import CloudKit


var gDesktopAppDelegate: ZDesktopAppDelegate?


@NSApplicationMain


class ZDesktopAppDelegate: NSResponder, NSMenuDelegate, ZApplicationDelegate {


    var needsSetup = true


    // MARK:- delegation
    // MARK:-


    func applicationDidBecomeActive(_ notification: Notification) {
        if  needsSetup {
            needsSetup          = false
            gDesktopAppDelegate = self

            UserDefaults.standard.set(true, forKey: "NSConstraintBasedLayoutVisualizeMutuallyExclusiveConstraint‌​s")
            gApplication.registerForRemoteNotifications(matching: .badge)
            gControllersManager.startupCloudAndUI()
            gEventsManager.setup()
        }
    }


    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)

        if  note.notificationType == .query {
            let queryNote: CKQueryNotification = note as! CKQueryNotification

            gRemoteStoresManager.receivedUpdateFor(queryNote.recordID!)
        }
    }

	
	func application(_ application: NSApplication, openFiles: [String]) {
		for file in openFiles {
			gRemoteStoresManager.cloudManager(for: .mineID)?.clear()
			gFileManager.readFile(from: file, into: .mineID)
		}
	}
	

    func applicationDidFinishLaunching(aNotification: NSNotification) {}


    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // print(deviceToken)
    }


    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error)
    }
    

    func applicationWillTerminate(aNotification: NSNotification) {
        for dbID in kAllDatabaseIDs {
            gFileManager.writeToFile(from: dbID)
        }
        
        // Insert code here to tear down your application
    }


    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        return .terminateNow
    }


    open func validateMenuItem(_ menuItem: ZMenuItem) -> Bool {
        return gEditingManager.validateKey(menuItem.keyEquivalent, menuItem.keyEquivalentModifierMask)
    }

    
    @IBAction func genericMenuHandler(_ iItem: NSMenuItem?) {
        if  gWorkMode == .graphMode {
            gEditingManager.handleMenuItem(iItem)
        }
    }

}
