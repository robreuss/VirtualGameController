//
//  VgcWatchConnectivity.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//

import Foundation
#if !(os(tvOS))
import WatchConnectivity

public class VgcWatchConnectivity: NSObject, WCSessionDelegate, NSURLSessionDelegate {

    var session: WCSession!
    var httpSession: NSURLSession!
    
    public override init() {
      
        super.init()
        
        session =  WCSession.defaultSession()
        session.delegate = self
        session.activateSession()
        
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
