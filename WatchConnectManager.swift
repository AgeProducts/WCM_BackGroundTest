//
//  WatchConnectManager.swift
//  WatchConnectManager
//
//  Created by Takuji Hori on 2018/07/06.
//  Copyright © 2018 Takuji Hori. All rights reserved.
//

import UIKit
import WatchKit
import WatchConnectivity

let FileTransferTmp_PreFix = "WatchCntMgr$$FileTransTmp_"

@objc protocol WatchConnectManagerDelegate: class {
    /*  receive */
    @objc optional func receiveApplicationContext(command:String, timeStamp:Date, subInfo:[String:Any])
    @objc optional func receiveUserInfo(command:String, timeStamp:Date, subInfo:[String:Any])
    @objc optional func receiveInteractiveMessage(command:String, timeStamp:Date, subInfo:[String:Any], replyHandler: @escaping ([String:Any]) -> Void)
    @objc optional func receiveTransferFile(fileURL:URL, command:String, timeStamp:Date, subInfo:[String:Any], file: WCSessionFile)
 
    /*  send result */
    @objc optional func receiveUserInfoDidFinish(command:String, timeStamp:Date, subInfo:[String:Any], userInfoTransfer: WCSessionUserInfoTransfer, error: Error?)
    @objc optional func receiveFileTransferDidFinish(command:String, timeStamp:Date, subInfo:[String:Any], fileTransfer: WCSessionFileTransfer, error: Error?)
    
    /*  connective status */
#if os(iOS)
    @objc optional func receiveStatusWatchStateDidChange(session : WCSession)
#endif
    @objc optional func receiveStatusReachabilityDidChange(reachability: Bool)
}

class WatchConnectManager: NSObject, WCSessionDelegate {
    
    static let sharedConnectManager = WatchConnectManager()
    private let WatchConnectManagerDelegates = NSHashTable<AnyObject>.weakObjects()
    
    private override init() {
        super.init()
    }
    
    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil
    private var aliveSession: WCSession? {
#if os(iOS)
        if let session = session, session.isPaired && session.isWatchAppInstalled {
            return session
        } else {
            return nil
        }
#else   // os(watchOS)
        return session
#endif
    }
    
    func startSession() -> Bool {
        if let Session = session {
            Session.delegate = self
            Session.activate()
            return true
        } else {
            return false
        }
    }
    
    // Managing Session Activation
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            Logger.error(message: "\(#function): session activation failed with error: \(error.localizedDescription)")
            return
        }
        Logger.info(message: "\(#function): session activationDidComplete with state: \(activationState.rawValue)") // 0: notActivated, 1: inactive, 2: activated
#if os(iOS)
//        Logger.debug(message: "\(#function): session watch directory URL: \(session.watchDirectoryURL?.absoluteString)")
#endif
    }
    
#if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        Logger.info(message: "\(#function): session did become inactive: \(session) \(session.activationState)")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        Logger.info(message: "\(#function): session did deactivate: \(session) \(session.activationState)")
        session.activate()
    }
#endif
    
    // Managing State Changes
#if os(iOS)
    func sessionWatchStateDidChange(_ session : WCSession) {
        Logger.info(message: "\(#function): session Watch state did change: \(session)  IsPaired: \(session.isWatchAppInstalled) AppInstalled: \(session.isPaired)")
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveStatusWatchStateDidChangeDelegate = indexDelegate.receiveStatusWatchStateDidChange {
                receiveStatusWatchStateDidChangeDelegate(session)
            }
        }
    }
#endif
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        Logger.info(message: "\(#function): session Reachability did change: \(session) \(session.isReachable)")
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveStatusReachabilityDidChangeDelegate = indexDelegate.receiveStatusReachabilityDidChange {
                receiveStatusReachabilityDidChangeDelegate(session.isReachable)
            }
        }
    }
    
    /* Multi watch support
     func configureDeviceDetailsWithApplicationContext(applicationContext: [String: Any]) {
     #if os(iOS)
     // Extract relevant values from the application context.
        guard let designator = applicationContext["designator"] as? String, let designatorColor = applicationContext["designatorColor"] as? String else {
            // If the expected values are unavailable in the `applicationContext`, inform the delegate using default values.
            delegate?.watchConnectivityManager(self, updatedWithDesignator: "-", designatorColor: "Blue")
            return
        }
     
     // Inform the delegate.
        delegate?.watchConnectivityManager(self, updatedWithDesignator: designator, designatorColor: designatorColor)
     #endif
     }
     */
    
    // Add Delegates
    func addWatchConnectManagerDelegate<T>(delegate: T) where T: WatchConnectManagerDelegate, T: Equatable {
        WatchConnectManagerDelegates.add(delegate)
    }

    // Remove
    func removeWatchConnectManagerDelegate<T>(delegate: T) where T:  WatchConnectManagerDelegate, T: Equatable {
        for indexDelegate in WatchConnectManagerDelegates.allObjects.reversed() {
            if indexDelegate === delegate as AnyObject {
                WatchConnectManagerDelegates.remove(delegate)
            }
        }
    }
    
    // Transfer Contents status
    @available(iOS 10.0, *)
    func hasTransferContentsPending() -> Bool? {
        return aliveSession?.hasContentPending
    }
    
    // Session ActivationState
    func sessionActivationState() -> WCSessionActivationState? {
        return aliveSession?.activationState
    }

    // Session Reachablity
    func sessionIsReachabie() -> Bool? {
        return aliveSession?.isReachable
    }

    // Make message args
    private func makeMessageCommon(command:String, addInfo:[Any]?) -> Dictionary<String,Any>? {
        if command.hasSuffix("$$") == false {
            Logger.error(message:"\(#function): command format error: \(command)")
            return nil
        }
        var infoDic = ["command":command as Any]                // Xcommand$$ = infoDic["command"]
        infoDic[command] = Date() as Any                        // timestamp =  infoDic["Xcommand$$"]
        addInfo?.enumerated().forEach { (index, addObj) in      // object = infoDic["Xcommand$$99"]
            if index < 100 {
                infoDic[command + String(format:"%02d",index)] = addObj
            } else {
                assertionFailure("\(#function): infoDic error. key count: \(infoDic.keys.count)")
            }
        }
        return infoDic
    }
}

// MARK: Application Context Data
extension WatchConnectManager {
    
    // API
    func zUpdateApplicationContext(_ command:String, addInfo:[Any]?) -> Bool {
        guard let _ = aliveSession else {
            Logger.error(message:"\(#function): Watch session, not Paired or not WatchAppInstalled! error")
            return false
        }
        guard let infoDic = makeMessageCommon(command: command, addInfo:addInfo) else {
            Logger.error(message: "\(#function): infoDic error")
            return false
        }
        do {
            try updateApplicationContext(infoDic)
        } catch {
            Logger.error(message: "\(#function): updateApplicationContext send error:\(error.localizedDescription)")
            return false
        }
        return true
    }
    
    // Sender
    private func updateApplicationContext(_ applicationContext: [String:Any]) throws {
        if let session = aliveSession {
            do {
                try session.updateApplicationContext(applicationContext)
            } catch let error {
                throw error
            }
        }
    }
    
    // Receiver : Receiving ApplicationContext
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String:Any]) {
        // handle receiving application context
        guard let command = applicationContext["command"] as? String,
            let timeStamp = applicationContext[command] as? Date else {
                Logger.error(message: "\(#function): format error. applicationContext: \(applicationContext)")
                return
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveApplicationContextDelegate = indexDelegate.receiveApplicationContext {
                receiveApplicationContextDelegate(command, timeStamp, applicationContext)
            }
        }
    }
}

// MARK: Transfer User Info Data
extension WatchConnectManager {
    
    // API
    func zTransferUserInfo(_ command:String, addInfo:[Any]?) -> WCSessionUserInfoTransfer? {
        guard let _ = aliveSession else {
            Logger.error(message:"\(#function): Watch session, not Paired or not WatchAppInstalled! error")
            return nil
        }
        guard let infoDic = makeMessageCommon(command: command, addInfo:addInfo) else {
            Logger.error(message: "\(#function): infoDic error")
            return nil
        }
        return transferUserInfo(infoDic)
    }
    
    // Sender
    private func transferUserInfo(_ userInfo: [String:Any] = [:]) -> WCSessionUserInfoTransfer? {
        return aliveSession?.transferUserInfo(userInfo)
    }
    
    /* now not use
    func transferCurrentComplicationUserInfo(_ userInfo: [String:Any] = [:]) -> WCSessionUserInfoTransfer? {
        return aliveSession?.transferUserInfo(userInfo)
    }  */
    
//    func remainingComplicationUserInfoTransfers() -> Int? {
//        return aliveSession?.remainingComplicationUserInfoTransfers
//    }
    
    func outstandingUserInfoTransfers() -> [WCSessionUserInfoTransfer]? {
        return aliveSession?.outstandingUserInfoTransfers
    }
    
    // Receiver : Transfer UserInfo did finished
    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        let userInfo = userInfoTransfer.userInfo as [String:Any]
        guard let command = userInfo["command"] as? String,
            let timeStamp = userInfo[command] as? Date else {
                Logger.error(message: "\(#function): format error. userInfoTransfer: \(userInfoTransfer)")
                return
        }
        if let error = error {
            Logger.error(message: "\(#function): is error. \(error.localizedDescription)")
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveUserInfoDidFinishDelegate = indexDelegate.receiveUserInfoDidFinish {
                receiveUserInfoDidFinishDelegate(command, timeStamp, userInfo, userInfoTransfer, error)
            }
        }
    }
    
    // Receiver : receiving UserInfo
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String:Any] = [:]) {
        guard let command = userInfo["command"] as? String,
            let timeStamp = userInfo[command] as? Date else {
                Logger.error(message: "\(#function): format error. userInfo: \(userInfo)")
                return
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveUserInfoDelegate = indexDelegate.receiveUserInfo {
                receiveUserInfoDelegate(command, timeStamp, userInfo)
            }
        }
    }
}

// MARK: Transfer File
extension WatchConnectManager {
    
    // API
    func zTransferFile(_ file:URL, command:String, addInfo:[Any]?) -> WCSessionFileTransfer? {
        guard let _ = aliveSession else {
            Logger.error(message:"\(#function): Watch session, not Paired or not WatchAppInstalled! error")
            return nil
        }
        guard let infoDic = makeMessageCommon(command: command, addInfo:addInfo) else {
            Logger.error(message: "\(#function): infoDic error")
            return nil
        }
        return transferFile(file, metadata: infoDic)
    }
    
    // Sender
    private func transferFile(_ file: URL, metadata: [String:Any]?) -> WCSessionFileTransfer? {
        return aliveSession?.transferFile(file as URL, metadata: metadata)
    }
    
    func outstandingFileTransfers() -> [WCSessionFileTransfer]? {
        return aliveSession?.outstandingFileTransfers
    }
    
    // Receiver : Transfer file did finished
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        let file = fileTransfer.file as WCSessionFile
        guard let metadata = file.metadata,
            let command = metadata["command"] as? String,
            let timeStamp = metadata[command] as? Date else {
            Logger.error(message: "\(#function): format error. fileTransfer: \(fileTransfer)")
            return
        }
        if let error = error {
            Logger.error(message: "\(#function): is error. \(error.localizedDescription)")
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveFileTransferDidFinishDelegate = indexDelegate.receiveFileTransferDidFinish {
                receiveFileTransferDidFinishDelegate(command, timeStamp, metadata, fileTransfer, error)
            }
        }
    }
    
    // Receiver : receiving file
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let metadata = file.metadata,
            let command = metadata["command"] as? String,
            let timeStamp = metadata[command] as? Date else {
                Logger.error(message: "\(#function): format error. file: \(file)")
                return
        }
        /* copy file to tmp */
        let path = file.fileURL.path
        let fileName = FileTransferTmp_PreFix + NSUUID().uuidString + "_" + (path as NSString).lastPathComponent
        let tmpPath = FileHelper.temporaryDirectoryWithFileName(fileName: fileName)                 // If you want other than "Temporary Directory", rewrite it here.
        guard let tmpUrl = URL(string: tmpPath) else { return }
        if FileHelper.copyFile(fromPath: path, toPath: tmpPath) == false {
            Logger.error(message: "\(#function): TMP file copy error")
            return
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveTransferFileDelegate = indexDelegate.receiveTransferFile {
                receiveTransferFileDelegate(tmpUrl, command, timeStamp, file.metadata!, file)
            }
        }
    }
}

// MARK: Interactive Messaging
extension WatchConnectManager {
    
    // Live messaging! App has to be reachable
    private var aliveReachableSession: WCSession? {
        if let session = aliveSession, session.isReachable {
                return session
        }
        return nil
    }
    
    // API
    func zSendInteractiveMessage(_ command:String, addInfo:[Any]?, replyHandler: (([String:Any]) -> Void)? = nil , errorHandler: ((Error) -> Void)? = nil)  -> Bool {
        
        // Request Interactive Message
        guard let _ = aliveSession else {
            Logger.error(message:"\(#function): Watch session, not Paired or not WatchAppInstalled! error")
            return false
        }
        guard let _ = aliveReachableSession else {
            Logger.info(message:"\(#function): Watch session, not Reachable")
            return false
        }
        guard let infoDic = makeMessageCommon(command: command, addInfo:addInfo) else {
            Logger.error(message: "\(#function): infoDic error")
            return false
        }
        sendMessage(infoDic, replyHandler: { replyDict in
            replyHandler?(replyDict)

        }, errorHandler: { error in
            //  Ignore error : [Error_Message_reply_took_too_long_code_7012_WCSession_Watch_OS2]
            if (error._code != 7012) {
                Logger.error(message: "\(#function): Send message error: \(error.localizedDescription) code: \(error._code)")
                errorHandler?(error)
            } else {
                Logger.error(message: "Ignore error. code: \(error._code)")
            }
        })
        return true
    }

    // Sender
    private func sendMessage(_ message: [String:Any], replyHandler: (([String:Any]) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        aliveReachableSession?.sendMessage(message, replyHandler: replyHandler, errorHandler: errorHandler)
    }
    
    // Receiver : receiving Immediate Messages
    func session(_ session: WCSession, didReceiveMessage message: [String:Any], replyHandler: @escaping ([String:Any]) -> Void) {
        guard let command = message["command"] as? String,
            let timeStamp = message[command] as? Date else {
            Logger.error(message: "\(#function): format error. message: \(message)")
            return
        }
        for case let indexDelegate as WatchConnectManagerDelegate in self.WatchConnectManagerDelegates.allObjects {
            if let receiveInteractiveMessageDelegate = indexDelegate.receiveInteractiveMessage {
                receiveInteractiveMessageDelegate(command, timeStamp, message, replyHandler)
            }
        }
    }

    /* Now NOT USE, Data version, Sender
    func sendMessageData(_ data: Data, replyHandler: ((Data) -> Void)? = nil, errorHandler: ((Error) -> Void)? = nil) {
        aliveReachableSession?.sendMessageData(data, replyHandler: replyHandler, errorHandler: errorHandler)
    }
    
    // Receiver
    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        Logger.warning(message: "\(#function): Now NOT USE! session:didReceiveMessageData:Data")
    }

    func session(_ session: WCSession, didReceiveMessageData messageData: Data, replyHandler: @escaping (Data) -> Void) {
        Logger.warning(message: "\(#function): Now NOT USE! session:didReceiveMessageData:Data:replyHandler")
    } */

    
    // Local Utility
    fileprivate class Logger {
    
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

    fileprivate class FileHelper {

        // tmp/fileName
        static func temporaryDirectoryWithFileName(fileName: String) -> String {
            return NSTemporaryDirectory() + "/" + fileName
        }
    
        static func copyFile(fromPath: String, toPath: String) -> Bool {
            do {
                try FileManager.default.copyItem(atPath: fromPath, toPath: toPath)
                return true
            } catch let error as NSError {
                print ("File copy error: \(error.localizedDescription) \(fromPath) \(toPath)")
                return false
            }
        }
    }
}





