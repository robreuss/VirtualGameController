//
//  VgcWatchConnectivity.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//

import Foundation
#if !(os(tvOS)) && !(os(OSX))
import WatchConnectivity
    
public class VgcWatchConnectivity: NSObject, WCSessionDelegate, NSURLSessionDelegate {

    public let elements = Elements()
    var session: WCSession!
    var httpSession: NSURLSession!
    public var motion: VgcMotionManager!
    
    public override init() {
      
        super.init()
        
        session =  WCSession.defaultSession()
        session.delegate = self
        session.activateSession()
        
        #if os(watchOS)
        motion = VgcMotionManager()
        motion.elements = VgcManager.elements
        motion.deviceSupportsMotion = true
        //motion.updateInterval = 1.0 / 30
        
        motion.watchConnectivity = self
        #endif
    }
    
    public func sendElementValueToBridge(element: Element) {

        if session.reachable {
            let message = ["\(element.type.rawValue)": element.value]
            session.sendMessage(message , replyHandler: { (content:[String : AnyObject]) -> Void in
                print("Phone: Our counterpart sent something back. This is optional")
                }, errorHandler: {  (error ) -> Void in
                    print("Phone: We got an error from our paired device : \(error)")
            })
        }
    }
    
}
#endif
