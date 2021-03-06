//
//  ZMobileAppDelegate.swift
//  Thoughtful
//
//  Created by Jonathan Sand on 7/7/16.
//  Copyright © 2016 Jonathan Sand. All rights reserved.
//


import UIKit
import CloudKit
import UserNotifications


@UIApplicationMain


class ZMobileAppDelegate: UIResponder, ZApplicationDelegate {


    var window: UIWindow?


    // MARK:- delegation
    // MARK:-

    
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        application.applicationSupportsShakeToEdit = true

        // application.registerUserNotificationSettings(.badgeSetting)
        application.registerForRemoteNotifications()
        gControllers.startupCloudAndUI()

        return true
    }


    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        let note: CKNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        
        if  note.notificationType == .query,
            let queryNote = note as? CKQueryNotification {
            gRemoteStorage.receiveFromCloud(queryNote)
        }
    }


    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        printDebug(.error, deviceToken)
    }


    @nonobjc public func application(_ application: UIApplication, didRegister notificationSettings: UNNotificationSettings) {
        printDebug(.error, notificationSettings)
    }


    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        performance("cloud registration error: \(error)")
    }
}

