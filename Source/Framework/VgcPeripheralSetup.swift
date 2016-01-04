//
//  PeripheralSetup.swift
//  
//
//  Created by Rob Reuss on 11/28/15.
//
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#endif

#if os(OSX)
    import AppKit
#endif

#if !os(watchOS)

public class VgcPeripheralSetup: NSObject {
    
    public var profileType: ProfileType!
    public var motionActive = false
    public var enableMotionUserAcceleration = true
    public var enableMotionRotationRate = true
    public var enableMotionAttitude = true
    public var enableMotionGravity = true
    
    /*
    public var motionActive: Bool! {
        didSet {
            if VgcManager.appRole == .Peripheral {
                if self.motionActive == true {
                    VgcManager.peripheral.motion.start()
                } else {
                    VgcManager.peripheral.motion.stop()
                }
            }
        }
    }
    */
    
#if os(iOS) || os(tvOS)
    public var backgroundColor: UIColor!
    
    public override init() {
        self.profileType = .ExtendedGamepad
        self.backgroundColor = UIColor.darkGrayColor()
    }
    
    public init(profileType: ProfileType, backgroundColor: UIColor) {
        self.profileType = profileType
        self.backgroundColor = backgroundColor
        super.init()
    }

#endif
    
#if os(OSX)
    public var backgroundColor: NSColor!
    
    public override init() {
        self.profileType = .ExtendedGamepad
        self.backgroundColor = NSColor.darkGrayColor()
    }
    
    public init(profileType: ProfileType, backgroundColor: NSColor) {
        self.profileType = profileType
        self.backgroundColor = backgroundColor
        super.init()
    }
#endif
    
required convenience public init(coder decoder: NSCoder) {
    
    self.init()

    #if os(OSX)
    self.backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! NSColor
    #endif
    
    #if os(iOS) || os(tvOS)
    self.backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! UIColor
    #endif
    
    self.profileType = ProfileType(rawValue: decoder.decodeIntegerForKey("profileType"))

    self.motionActive = decoder.decodeBoolForKey("motionActive")
    self.enableMotionUserAcceleration = decoder.decodeBoolForKey("enableMotionUserAcceleration")
    self.enableMotionAttitude = decoder.decodeBoolForKey("enableMotionAttitude")
    self.enableMotionGravity = decoder.decodeBoolForKey("enableMotionGravity")
    self.enableMotionRotationRate = decoder.decodeBoolForKey("enableMotionRotationRate")

}

    
    public override var description: String {
        
        var result: String = "\n"
        result += "Peripheral Setup:\n\n"
        result += "Profile Type:             \(self.profileType)\n"
        result += "Background Color:         \(self.backgroundColor)\n"
        result += "Motion:\n"
        result += "  Active:                 \(self.motionActive)\n"
        result += "  User Acceleration:      \(self.enableMotionUserAcceleration)\n"
        result += "  Gravity:                \(self.enableMotionGravity)\n"
        result += "  Rotation Rate:          \(self.enableMotionRotationRate)\n"
        result += "  Attitude:               \(self.enableMotionAttitude)\n"
        return result
        
    }
    
    // Test
    
    public func encodeWithCoder(coder: NSCoder) {
        
        coder.encodeInteger(self.profileType.rawValue, forKey: "profileType")
        coder.encodeObject(self.backgroundColor, forKey: "backgroundColor")
        coder.encodeBool(self.motionActive, forKey: "motionActive")
        coder.encodeBool(self.enableMotionUserAcceleration, forKey: "enableMotionUserAcceleration")
        coder.encodeBool(self.enableMotionAttitude, forKey: "enableMotionAttitude")
        coder.encodeBool(self.enableMotionGravity, forKey: "enableMotionGravity")
        coder.encodeBool(self.enableMotionRotationRate, forKey: "enableMotionRotationRate")
    }
    
    // A copy of the deviceInfo object is made when forwarding it through a Bridge.
    func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = VgcPeripheralSetup(profileType: profileType, backgroundColor: backgroundColor)
        return copy
    }
    
    public func sendToController(controller: VgcController) {
        
        if controller.hardwareController != nil {
            vgcLogDebug("Refusing to send peripheral setup to hardware controller")
            return
        }
        
        vgcLogDebug("Sending Peripheral Setup to Peripheral:")
        print(self)
        
        NSKeyedArchiver.setClassName("VgcPeripheralSetup", forClass: VgcPeripheralSetup.self)
        let element = VgcManager.elements.peripheralSetup
        element.value = NSKeyedArchiver.archivedDataWithRootObject(self)
       controller.sendElementStateToPeripheral(element)
    }
    
    
}

#endif

/*
required convenience public init(coder decoder: NSCoder) {

#if os(OSX)
let backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! NSColor
#endif

#if os(iOS) || os(tvOS)
let backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! UIColor
#endif

let profileType = ProfileType(rawValue: decoder.decodeIntegerForKey("profileType"))

self.init(profileType: profileType!, backgroundColor: backgroundColor)

}

*/