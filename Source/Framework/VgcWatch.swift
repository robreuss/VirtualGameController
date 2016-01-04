//
//  VgcWatch.swift
//  
//
//  Created by Rob Reuss on 12/18/15.
//
//

import Foundation
#if os(iOS)
import WatchConnectivity
#endif

#if !os(watchOS)

@objc internal protocol VgcWatchDelegate {
    
    func receivedWatchMessage(element: Element)
    
}

public let VgcWatchDidConnectNotification:     String = "VgcWatchDidConnectNotification"
public let VgcWatchDidDisconnectNotification:  String = "VgcWatchDidDisconnectNotification"

#if os(iOS)
public class VgcWatch: NSObject, WCSessionDelegate {
    
    var delegate: VgcWatchDelegate!
    var wcSession: WCSession!
    var watchController: VgcController!
    var centralPublisher: VgcCentralPublisher!
    public var reachable: Bool = false
    
    public typealias VgcValueChangedHandler = (Element) -> Void
    public var valueChangedHandler: VgcValueChangedHandler!
    
    init(delegate: VgcWatchDelegate) {
        
        self.delegate = delegate
        
        super.init()
        
        scanForWatch()
        
    }
    
    func scanForWatch() {

        
        if WCSession.isSupported() {
            vgcLogDebug("Watch connectivity is supported, activating")
            if self.wcSession == nil {
                vgcLogDebug("Setting up watch session")
                self.wcSession = WCSession.defaultSession()
                self.wcSession.delegate = self
            }
            self.wcSession.activateSession()
            if self.wcSession.paired == false {
                vgcLogDebug("There is no watch paired with this device")
                return
            }
            if self.wcSession.watchAppInstalled == false {
                vgcLogDebug("The watch app is not installed")
                return
            }
            if self.wcSession.reachable == true {
                
                vgcLogDebug("Watch is reachable")
                reachable = wcSession.reachable
                
                NSNotificationCenter.defaultCenter().postNotificationName(VgcWatchDidConnectNotification, object: nil)
                
            } else {
                vgcLogDebug("Watch is not reachable")
            }
        } else {
            vgcLogDebug("Watch connectivity is not supported on this platform")
        }
        
    }
    
    public func sessionReachabilityDidChange(session: WCSession) {
        
        vgcLogDebug("Watch reachability changed to \(session.reachable)")
        reachable = wcSession.reachable
        
        if reachable {
            
            NSNotificationCenter.defaultCenter().postNotificationName(VgcWatchDidConnectNotification, object: nil)

        } else {
            
            NSNotificationCenter.defaultCenter().postNotificationName(VgcWatchDidDisconnectNotification, object: nil)

        }
        
    }
    
    public func session(session: WCSession, didReceiveMessage message: [String : AnyObject], replyHandler: ([String : AnyObject]) -> Void) {
        
        vgcLogDebug("Watch connectivity received message: " + message.description)
        for elementTypeString: String in message.keys {
            
            let element = VgcManager.elements.elementFromIdentifier(Int(elementTypeString)!)
            element.value = message[elementTypeString]!
            
            if let handler = valueChangedHandler {
                handler(element)
            } else {
                delegate.receivedWatchMessage(element)
            }
            
        }
    }
    
    public func sendElementState(element: Element) {
        
        if wcSession != nil && wcSession.reachable {
            let message = ["\(element.identifier)": element.value]
            wcSession.sendMessage(message , replyHandler: { (content:[String : AnyObject]) -> Void in
                vgcLogDebug("Watch Connectivity: Our counterpart sent something back. This is optional")
                }, errorHandler: {  (error ) -> Void in
                    vgcLogDebug("Watch Connectivity: We got an error from our paired device : \(error)")
            })
        }
        
    }
}
#endif
#endif
