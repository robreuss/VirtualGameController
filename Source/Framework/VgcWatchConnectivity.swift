//
//  VgcWatchConnectivity.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//

import Foundation
#if !(os(tvOS)) && !(os(OSX))
import WatchKit
import WatchConnectivity
    
public class VgcWatchConnectivity: NSObject, WCSessionDelegate, NSURLSessionDelegate {

    public let elements = Elements()
    var session: WCSession!
    var httpSession: NSURLSession!
    public var motion: VgcMotionManager!
    
    public typealias VgcValueChangedHandler = (Element) -> Void
    public var valueChangedHandler: VgcValueChangedHandler!
    
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
    
    public func sendElementState(element: Element) {
        
        if session.reachable {
            let message = ["\(element.identifier)": element.value]
            vgcLogDebug("Watch connectivity sending message: \(message) for element \(element.name) with value \(element.value)")
            session.sendMessage(message , replyHandler: { (content:[String : AnyObject]) -> Void in
                // Response to message shows up here
                }, errorHandler: {  (error ) -> Void in
                    vgcLogError("Received an error while attempt to send element \(element) to bridge: \(error)")
            })
        } else {
            vgcLogError("Unable to send element \(element) because bridge is unreachable")
        }
    }

    public func session(session: WCSession, didReceiveMessage message: [String : AnyObject]) {
        
        vgcLogDebug("Received message: \(message)")
        
        for elementTypeString: String in message.keys {
            
            let element = elements.elementFromIdentifier(Int(elementTypeString)!)
            element.value = message[elementTypeString]!
            
            if element.identifier == elements.vibrateDevice.identifier {
                
                #if os(watchOS)
                    WKInterfaceDevice.currentDevice().playHaptic(WKHapticType.Click)
                #endif
                
            } else {

                vgcLogDebug("Calling handler with element: \(element.identifier): \(element.value)")
                
                if let handler = valueChangedHandler {
                    handler(element)
                }
                
            }
            
        }
    }
    
    public func sessionReachabilityDidChange(session: WCSession) {
        
        vgcLogDebug("Reachability changed to \(session.reachable)")

        if session.reachable == false {
            vgcLogDebug("Stopping motion")
            motion.stop()
        }
        
    }
    
}
#endif
