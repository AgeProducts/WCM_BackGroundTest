//
//  InterfaceController.swift
//  WCM_BackGround.watchkitapp Extension
//
//  Created by 堀 卓司 on 2018/08/29.
//  Copyright © 2018 Takuji Hori. All rights reserved.
//

import WatchKit
import WatchConnectivity

class InterfaceController: WKInterfaceController, WatchConnectManagerDelegate {
    
    let WCMshare = WatchConnectManager.sharedConnectManager
    var recvCount = 0
    
    @IBOutlet var messageLabel: WKInterfaceLabel!
    
    let dateformatter2: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "hh:mm:ss.SSS"
        return f
    }()
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        WCMshare.addWatchConnectManagerDelegate(delegate: self)
        if WCMshare.startSession() == false {
            loggerDebug(message: "No session stop")
            assertionFailure("No session stop")
        }
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    @IBAction func buttonAct() {
        print("\(#function): Not use now!")
        DispatchQueue.main.async {
            self.messageLabel.setText("Not use now!")
        }
    }
    
    // Receiver / Delagete
    func receiveApplicationContext(command:String, timeStamp:Date, subInfo:[String:Any]) {
        if command == "AplContextCMD$$",
            let sendCount = subInfo[command + "00"] as? Int,
            let sendDate = subInfo[command + "01"] as? Date {
            recvCount += 1
            let message = String(format: "%@ send[%d, %@] recv[%d, %@]", command, sendCount,  dateformatter2.string(from: sendDate), recvCount,  dateformatter2.string(from: Date()))
            DispatchQueue.main.async {
                self.messageLabel.setText(message)
            }
            remoteLog(message: message)
        }
    }
    
    func receiveUserInfo(command:String, timeStamp:Date, subInfo:[String:Any]) {
        if command == "UserInfoCMD$$",
            let sendCount = subInfo[command + "00"] as? Int,
            let sendDate = subInfo[command + "01"] as? Date {
            recvCount += 1
            let message = String(format: "%@ send[%d, %@] recv[%d, %@]", command, sendCount,  dateformatter2.string(from: sendDate), recvCount,  dateformatter2.string(from: Date()))
            DispatchQueue.main.async {
                self.messageLabel.setText(message)
            }
            remoteLog(message: message)
        }
    }
    
    func receiveTransferFile(fileURL:URL, command:String, timeStamp:Date, subInfo:[String:Any], file: WCSessionFile) {
        if command == "FileTansCND$$",
            let sendCount = subInfo[command + "00"] as? Int,
            let sendDate = subInfo[command + "01"] as? Date {
            recvCount += 1
//            var filesize = "file size error"
//            if let size = fileSizePath(path: fileURL.path) {
//                filesize = Misc.unitSizeString(size: size)
//            }
            let message = String(format: "%@ send[%d, %@] recv[%d, %@]", command, sendCount,  dateformatter2.string(from: sendDate), recvCount,  dateformatter2.string(from: Date()))
            DispatchQueue.main.async {
                self.messageLabel.setText(message)
            }
            remoteLog(message: message)
        }
    }
    
    // Remoto log Sender
    func remoteLog(message: String) {
        if WCMshare.zTransferUserInfo("RemotoLog$$", addInfo:[message]) == nil {
            loggerDebug(message: "TemotoLog UserInfo error")
        }
    }

//    func remoteLog(message: String) {
//        if  WCMshare.zSendInteractiveMessage("RemotoLog$$", addInfo:[message]) == false {
//            loggerDebug(message: "RemotoLog Send message error")
//        }
//    }

    func loggerDebug(message: String) {
        DispatchQueue.main.async {
            self.messageLabel.setText(message)
            print(message)
        }
    }
    
    // tiny FileHandler
//    func fileExists(path: String) -> Bool {
//        return FileManager.default.fileExists(atPath: path)
//    }
//
//    func readFileWithData(path: String) -> Data? {
//        if fileExists(path: path) == false {
//            return nil
//        }
//        guard let fileHandle = FileHandle(forReadingAtPath: path) else {
//            return nil
//        }
//        let data = fileHandle.readDataToEndOfFile()
//        fileHandle.closeFile()
//        return data
//    }
//
//    func fileSizePath(path: String) -> Int? {
//        if fileExists(path: path) == false {
//            return nil
//        }
//        do {
//            let attributes = try FileManager.default.attributesOfItem(atPath: path) as NSDictionary
//            return Int(attributes.fileSize())
//        }
//        catch let error as NSError {
//            NSLog ("File size error: \(error.localizedDescription) \(path)")
//            return nil
//        }
//    }
}

//class Misc {
//    static func unitSizeString(size: Int) -> String {
//        var unit = ""
//        var Size = size
//        switch Size {
//        case 0..<1024:
//            unit = "b"
//        case 1024..<(1024*1024):
//            Size = Size / 1024
//            unit = "k"
//        case (1024*1024)..<(1024*1024*1024):
//            Size = Size / (1024*1024)
//            unit = "m"
//        default:
//            unit = "Size Error"
//        }
//        return String(Size) + unit
//    }
//}

