//
//  ViewController.swift
//  WCM_BackGround
//
//  Created by 堀 卓司 on 2018/08/29.
//  Copyright © 2018 Takuji Hori. All rights reserved.
//

//
//  ViewController.swift
//  WCM_TinyBG
//
//  Created by 堀 卓司 on 2018/08/14.
//  Copyright © 2018 Takuji Hori. All rights reserved.
//

import WatchKit
import WatchConnectivity

class ViewController: UIViewController, WatchConnectManagerDelegate {
    
    let WCMshare = WatchConnectManager.sharedConnectManager
    @IBOutlet weak var textView: UITextView!
    
    var sendCount = 0
    var url:URL?
    
    let dateformatter2: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm:ss.SSS"
        return f
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        url = URL(fileURLWithPath:Bundle.main.path(forResource: "CatPhoto00", ofType: "jpg")!)
        WCMshare.addWatchConnectManagerDelegate(delegate: self)
        if WCMshare.startSession() == false {
            loggerDebug(message: "No session stop")
            assertionFailure("No session stop")
        }
    }
    
// Sender
    @IBAction func aplContxButton(_ sender: Any) {
        sendCount += 1
        loggerDebug(message: "\(#function): Send aplContext: \(sendCount)")
        if WCMshare.zUpdateApplicationContext("AplContextCMD$$", addInfo:[sendCount, Date()]) == false {
            loggerDebug(message: "request AplContext error")
        }
    }
    
    @IBAction func userInfoButton(_ sender: Any) {
        sendCount += 1
        loggerDebug(message: "\(#function): Send userInfo: \(sendCount)")
        if WCMshare.zTransferUserInfo("UserInfoCMD$$", addInfo:[sendCount, Date()]) == nil {
            loggerDebug(message: "request UserInfo error")
        }
    }
    
    @IBAction func fileTansferButton(_ sender: Any) {
        sendCount += 1
        loggerDebug(message: "\(#function): Send fileTansfer: \(sendCount)")
        if WCMshare.zTransferFile(url!, command: "FileTansCND$$", addInfo:[sendCount, Date()]) == nil {
            loggerDebug(message: "\(#function): request FileTansfer error.")
        }
    }
    
// Status change / Delagete
    func receiveStatusReachabilityDidChange(reachability: Bool) {
        if reachability == true {
            loggerDebug(message: "Reachable")
        } else {
            loggerDebug(message: "Not Reachable")
        }
    }
    
// Sender / complete
    func receiveUserInfoDidFinish(command:String, timeStamp:Date, subInfo:[String:Any], userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        if command == "UserInfoCMD$$" {
//            loggerDebug(message:"\(#function): UserInfo complete")
            loggerDebug(message:"Send UserInfo complete")
        }
    }
    
    func receiveFileTransferDidFinish(command:String, timeStamp:Date, subInfo:[String:Any], fileTransfer: WCSessionFileTransfer, error: Error?) {
        if command == "FileTansCND$$" {
//            loggerDebug(message:"\(#function): FileTransfer complete")
            loggerDebug(message:"Send FileTransfer complete")
        }
    }
    
// Receiver (Remoto Log message) Delagete
    func receiveUserInfo(command:String, timeStamp:Date, subInfo:[String:Any]) {
        if command == "RemotoLog$$" {
            if let remotoMessage = subInfo["RemotoLog$$00"] as? String  {
                loggerDebug(message: "Remote >> " + remotoMessage)
            }
        }
    }

//    func receiveInteractiveMessage(command:String, timeStamp:Date, subInfo:[String:Any], replyHandler: @escaping ([String:Any]) -> Void) {
//        if command == "RemotoLog$$" {
//            if let remotoMessage = subInfo["RemotoLog$$00"] as? String  {
//                loggerDebug(message: "Remote >> " + remotoMessage)
//            }
////            replyHandler(["RemotoLog$$":"receive", "MyNameIs":"iOS"])
//        }
//    }
    
    func loggerDebug(message: String, clear:Bool = false) {
        print(message)
        DispatchQueue.main.async {
            if clear == true {
                self.textView.text = ""
            }
            self.textView.isScrollEnabled = false
            self.textView.text = self.textView.text + message + "\n"
            self.textView.selectedRange = NSRange(location: self.textView.text.characters.count, length: 0)
            self.textView.isScrollEnabled = true
            let scrollY = self.textView.contentSize.height - self.textView.bounds.height
            let scrollPoint = CGPoint(x: 0, y: scrollY > 0 ? scrollY : 0)
            self.textView.setContentOffset(scrollPoint, animated: true)
        }
    }
    
//    func loggerDebug(message: String) {
//        DispatchQueue.main.async {
//            self.textView.text = message
//            print(message)
//        }
//    }
}
