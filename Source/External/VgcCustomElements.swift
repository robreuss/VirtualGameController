//
//  VgcCustomElements.swift
//  
//
//  Created by Rob Reuss on 10/11/15.
//
//

import Foundation
import VirtualGameController

public enum CustomElementType: Int {
    
    case FiddlestickX   = 50
    case FiddlestickY   = 51
    case FiddlestickZ   = 52
    case Keyboard       = 53
    
}

public class CustomElements: CustomElementsSuperclass {

    override init() {
        
        super.init()
        
        ///
        /// CUSTOMIZE HERE
        ///
        /// Create a constructor for each of your custom elements.  
        ///
        /// - parameter name: Human-readable name, used in logging
        /// - parameter dataType: Supported types include .Float, .String and .Int
        /// - parameter type: Unique identifier, numbered beginning with 100 to keep them out of collision with standard elements
        ///
        
        customProfileElements = [
            CustomElement(name: "Fiddlestick X", dataType: .Float, type:CustomElementType.FiddlestickX.rawValue),
            CustomElement(name: "Fiddlestick Y", dataType: .Float, type:CustomElementType.FiddlestickY.rawValue),
            CustomElement(name: "Fiddlestick Z", dataType: .Float, type:CustomElementType.FiddlestickZ.rawValue),
            CustomElement(name: "Keyboard", dataType: .String, type:CustomElementType.Keyboard.rawValue)
        ]

    }

}


