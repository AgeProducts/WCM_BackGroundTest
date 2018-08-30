//
//  ExtensionDelegate.swift
//  WCM_TinyBG.watchkitapp Extension
//
//  Created by 堀 卓司 on 2018/08/14.
//  Copyright © 2018 Takuji Hori. All rights reserved.
//

#if BACKGROUND_A

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    // for BackGround
    let WCMshare = WatchConnectManager.sharedConnectManager
    var wcBackgroundTasks: [WKWatchConnectivityRefreshBackgroundTask]
    
    override init() {
             
        wcBackgroundTasks = []
        super.init()
        
        //        let defaultSession = WCSession.default
        //        defaultSession.delegate = WCMshare
        
        if WCMshare.startSession() == false {
            NSLog("No session stop")
            assertionFailure("No session stop")
        }
        
        /*
         Here we add KVO on the session properties that this class is interested in before activating
         the session to ensure that we do not miss any value change events
         */
        WCMshare.addObserver(self, forKeyPath: "activationState", options: [], context: nil)
        WCMshare.addObserver(self, forKeyPath: "hasContentPending", options: [], context: nil)
        
        //        defaultSession.activate()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        DispatchQueue.main.async {
            Logger.debug(message: "\(#function): keyPath = \(keyPath)")
            self.completeAllTasksIfReady()
        }
    }
    
    // MARK: Background
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for backgroundTask in backgroundTasks {
            if let wcBackgroundTask = backgroundTask as? WKWatchConnectivityRefreshBackgroundTask {
                // store a reference to the task objects as we might have to wait to complete them
                Logger.debug(message: "\(#function): \(wcBackgroundTask) was appended!")
                self.wcBackgroundTasks.append(wcBackgroundTask)
            } else {
                // immediately complete all other task types as we have not added support for them
                Logger.debug(message: "\(#function): \(backgroundTask.description) was setTaskCompletedWithSnapshot")
                backgroundTask.setTaskCompleted()
            }
        }
        completeAllTasksIfReady()
    }
    
    // MARK: Convenience
    
    func completeAllTasksIfReady() {
        let session = WCSession.default
        // the session's properties only have valid values if the session is activated, so check that first
        
        //        Logger.debug(message: "\(#function): \(session.activationState) \(session.hasContentPending)")
        Logger.debug(message: "\(#function): \(WCMshare.sessionActivationState()) \(WCMshare.hasTransferContentsPending())")
        
        if WCMshare.sessionActivationState() == .activated && WCMshare.hasTransferContentsPending() == false {
            //      if session.activationState == .activated && !session.hasContentPending {
            wcBackgroundTasks.forEach { $0.setTaskCompleted() }
            wcBackgroundTasks.removeAll()
        }
    }
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        Logger.debug(message: "\(#function): ")
        print ("BACKGROUND_A")
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillEnterForeground() {
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationDidEnterBackground() {
        Logger.debug(message: "\(#function): ")
    }
}

#elseif BACKGROUND_B

import WatchKit
import WatchConnectivity

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
//    private lazy var sessionDelegater: SessionDelegater = {
//        return SessionDelegater()
//    }()
    
    private lazy var sessionDelegater: WatchConnectManager = {        // .replace
        return WatchConnectManager.sharedConnectManager
    }()
    
    // Hold the KVO observers as we want to keep oberving in the extension life time.
    //
    private var activationStateObservation: NSKeyValueObservation?
    private var hasContentPendingObservation: NSKeyValueObservation?
    
    // An array to keep the background tasks.
    //
    private var wcBackgroundTasks:[WKWatchConnectivityRefreshBackgroundTask]
    
    override init() {
        
        wcBackgroundTasks = []
        super.init()
        
        assert(WCSession.isSupported(), "This sample requires a platform supporting Watch Connectivity!")
        
//        if WatchSettings.sharedContainerID.isEmpty {              // .delete
//            print("Specify a shared container ID for WatchSettings.sharedContainerID to use watch settings!")
//        }
        
        // WKWatchConnectivityRefreshBackgroundTask should be completed – Otherwise they will keep consuming
        // the background executing time and eventually causes an app crash.
        // The timing to complete the tasks is when the current WCSession turns to not .activated or
        // hasContentPending flipped to false (see completeBackgroundTasks), so KVO is set up here to observe
        // the changes if the two properties.
        //
        activationStateObservation = WCSession.default.observe(\.activationState) { _, _ in
            Logger.debug(message: "\(#function): activationStateObservation: call completeBackgroundTasks()")   // .add
            DispatchQueue.main.async {
                self.completeBackgroundTasks()
            }
        }
        hasContentPendingObservation = WCSession.default.observe(\.hasContentPending) { _, _ in
            Logger.debug(message: "\(#function): hasContentPendingObservation: call completeBackgroundTasks()")
            DispatchQueue.main.async {
                self.completeBackgroundTasks()
            }
        }
        
        // Activate the session asynchronously as early as possible.
        // In the case of being background launched with a task, this may save some background runtime budget.
        //
        WCSession.default.delegate = sessionDelegater
        WCSession.default.activate()
    }
    
    // Compelete the background tasks, and schedule a snapshot refresh.
    //
    func completeBackgroundTasks() {
        guard !wcBackgroundTasks.isEmpty else {
            Logger.debug(message: "\(#function): \(!wcBackgroundTasks.isEmpty)")   // .add
            return
        }
        guard WCSession.default.activationState == .activated,
            WCSession.default.hasContentPending == false else {
                Logger.debug(message: "\(#function): \(WCSession.default.hasContentPending)")   // .add
                return
        }
        
//        wcBackgroundTasks.forEach { $0.setTaskCompleted() }                       // .replace
        wcBackgroundTasks.forEach {
            Logger.debug(message: "\(#function): completeBackgroundTasks: \($0)")   // .add
            $0.setTaskCompletedWithSnapshot(false)
        }
        
        // Use Logger to log the tasks for debug purpose. A real app may remove the log
        // to save the precious background time.
        //
        Logger.debug(message: "\(#function):\(wcBackgroundTasks) was completed!")       // .replace
        
        // Schedule a snapshot refresh if the UI is updated by background tasks.
        //
        let date = Date(timeIntervalSinceNow: 1)
        WKExtension.shared().scheduleSnapshotRefresh(withPreferredDate: date, userInfo: nil) { error in
            Logger.debug(message: "\(#function): WKExtension.shared().scheduleSnapshotRefresh")     // .add
            if let error = error {
//                print("scheduleSnapshotRefresh error: \(error)!")
                Logger.info(message: "\(#function): scheduleSnapshotRefresh error: \(error)!")     // .replace
            }
        }
        wcBackgroundTasks.removeAll()
    }
    
    // Be sure to complete all the tasks - otherwise they will keep consuming the background executing
    // time until the time is out of budget and the app is killed.
    //
    // WKWatchConnectivityRefreshBackgroundTask should be completed after the pending data is received
    // so retain the tasks first. The retained tasks will be completed at the following cases:
    // 1. hasContentPending flips to false, meaning all the pending data is received. Pending data means
    //    the data received by the device prior to the WCSession getting activated.
    //    More data might arrive, but it isn't pending when the session activated.
    // 2. The end of the handle method.
    //    This happens when hasContentPending can flip to false before the tasks are retained.
    //
    // If the tasks are completed before the WCSessionDelegate methods are called, the data will be delivered
    // the app is running next time, so no data lost.
    //
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            
            // Use Logger to log the tasks for debug purpose. A real app may remove the log
            // to save the precious background time.
            //
            if let wcTask = task as? WKWatchConnectivityRefreshBackgroundTask {
                wcBackgroundTasks.append(wcTask)
                Logger.debug(message: "\(#function):\(wcTask.description) was appended!")      // .replace
            } else {
//                task.setTaskCompleted()
                task.setTaskCompletedWithSnapshot(false)                                       // .replace
                Logger.debug(message: "\(#function):\(task.description) was completed!")       // .replace
            }
        }
        Logger.debug(message: "\(#function): call completeBackgroundTasks()")                 // .add
        completeBackgroundTasks()
    }
    
    //
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.
        Logger.debug(message: "\(#function): ")
        print ("BACKGROUND_B")
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillEnterForeground() {
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationDidEnterBackground() {
        Logger.debug(message: "\(#function): ")
    }
}

#else   // No BG / default

import WatchKit

class ExtensionDelegate: NSObject, WKExtensionDelegate {
    
    func applicationDidFinishLaunching() {
        // Perform any final initialization of your application.

        print ("NO BACKGROUND")
        
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationDidBecomeActive() {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillResignActive() {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, etc.
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationWillEnterForeground() {
        Logger.debug(message: "\(#function): ")
    }
    
    func applicationDidEnterBackground() {
        Logger.debug(message: "\(#function): ")
    }
    
    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
        for task in backgroundTasks {
            // Use a switch statement to check the task type
            switch task {
            case let backgroundTask as WKApplicationRefreshBackgroundTask:
                // Be sure to complete the background task once you’re done.
                backgroundTask.setTaskCompletedWithSnapshot(false)
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                // Snapshot tasks have a unique completion call, make sure to set your expiration date
                snapshotTask.setTaskCompleted(restoredDefaultState: true, estimatedSnapshotExpiration: Date.distantFuture, userInfo: nil)
            case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
                // Be sure to complete the connectivity task once you’re done.
                connectivityTask.setTaskCompletedWithSnapshot(false)
            case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
                // Be sure to complete the URL session task once you’re done.
                urlSessionTask.setTaskCompletedWithSnapshot(false)
            default:
                // make sure to complete unhandled task types
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
#endif

class Logger {
    
    class func debug (message: String = "") {
        NSLog("debug: \(message)")
    }
    class func info (message: String = "") {
        NSLog("info: \(message)")
    }
    class func warning (message: String = "") {
        NSLog("warning: \(message)")
    }
    class func error (message: String = "") {
        NSLog("error: \(message)")
    }
}


