//
//  VgcCentralPublisherWatch.swift
//  
//
//  Created by Rob Reuss on 10/30/15.
//
//

import Foundation
import WatchConnectivity

class CentralPublisherWatch: NSObject, WCSessionDelegate {
    
    var wcSession: WCSession!
    var watchController: VgcController!
    
    override init() {
        
        super.init()
        
    }
    
    func scanForWatchController() {
        
        if self.watchController != nil {
            
            dispatch_async(dispatch_get_main_queue()) {
                NSNotificationCenter.defaultCenter().postNotificationName("VgcControllerDidConnectNotification", object: self.watchController)
            }
            return
        }
        
        if WCSession.isSupported() {
            print("Watch connectivity is supported, activating")
            if self.wcSession == nil {
                print("Setting up watch session")
                self.wcSession = WCSession.defaultSession()
                self.wcSession.delegate = self
            }
            self.wcSession.activateSession()
            if self.wcSession.paired == false {
                print("There is no watch paired with this device")
                return
            }
            if self.wcSession.watchAppInstalled == false {
                print("The watch app is not installed")
                return
            }
            if self.wcSession.reachable == true {
                
                print("Watch is reachable, creating controller")
                
                watchController = VgcController()
                
                watchController.deviceInfo = DeviceInfo(deviceUID: NSUUID().UUIDString, vendorName: "Watch", attachedToDevice: false, profileType: .Watch, controllerType: .Watch, supportsMotion: true)
                
            } else {
                print("Watch is not reachable")
            }
        } else {
            print("Watch connectivity is not supported on this platform")
        }
        
    }
    
    internal func sessionReachabilityDidChange(session: WCSession) {
        
        print("Watch reachability changed to \(session.reachable)")
        if session.reachable {
            self.scanForWatchController()
        } else {
            if watchController != nil { watchController.disconnect() }
        }
        
    }
    
    internal func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        
        print("Watch connectivity received message: " + message.description)
        for elementTypeString: String in message.keys {
            
            let element = self.watchController.elements.elementFromIdentifier(Int(elementTypeString)!)
            element.value = message[elementTypeString]!
            self.watchController.updateGameControllerWithValue(element)
            
        }
    }    
}
