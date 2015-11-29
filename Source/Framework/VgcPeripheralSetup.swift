//
//  PeripheralSetup.swift
//  
//
//  Created by Rob Reuss on 11/28/15.
//
//

import Foundation
import UIKit

public class VgcPeripheralSetup: NSObject {
    
    public var backgroundColor: UIColor!
    public var profileType: ProfileType!
    
    public override init() {
        // my init
        self.backgroundColor = UIColor.darkGrayColor()
    }
    
    public init(profileType: ProfileType, backgroundColor: UIColor) {
        self.profileType = profileType
        self.backgroundColor = backgroundColor
        super.init()
    }
    
    required convenience public init(coder decoder: NSCoder) {
        
        let backgroundColor = decoder.decodeObjectForKey("backgroundColor") as! UIColor
        let profileType = ProfileType(rawValue: decoder.decodeIntegerForKey("profileType"))
        
        self.init(profileType: profileType!, backgroundColor: backgroundColor)
        
    }
    
    public override var description: String {
        
        var result: String = "\n"
        result += "Peripheral Setup:\n\n"
        result += "Profile Type:        \(self.profileType)\n"
        result += "Background Color:    \(self.backgroundColor)\n"

        return result
        
    }
    
    public func encodeWithCoder(coder: NSCoder) {
        
        coder.encodeInteger(self.profileType.rawValue, forKey: "profileType")
        coder.encodeObject(self.backgroundColor, forKey: "backgroundColor")
        
    }
    
    // A copy of the deviceInfo object is made when forwarding it through a Bridge.
    func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = VgcPeripheralSetup(profileType: profileType, backgroundColor: backgroundColor)
        return copy
    }
    
    public func sendToController(controller: VgcController) {
        
        if controller.hardwareController != nil {
            print("Refusing to send peripheral setup to hardware controller")
            return
        }
        
        print("Sending Peripheral Setup to Peripheral:")
        print(self)
        
        NSKeyedArchiver.setClassName("VgcPeripheralSetup", forClass: VgcPeripheralSetup.self)
        let element = VgcManager.elements.peripheralSetup
        element.value = NSKeyedArchiver.archivedDataWithRootObject(self)
       controller.sendElementStateToPeripheral(element)
    }
    
    
}