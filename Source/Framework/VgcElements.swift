//
//  VgcElement.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation

#if os(iOS) || os(OSX) || os(tvOS)
    import GameController
#endif

#if os(iOS) || os(WatchOS) || os(tvOS)
    import UIKit
#endif

public enum SystemMessages: Int, CustomStringConvertible {
    
    case Disconnect = 100
    case ReceivedInvalidMessage = 101
    
    public var description : String {
        
        switch self {
        case .Disconnect: return "Disconnect"
        case .ReceivedInvalidMessage: return "Received invalid message"
            
        }
    }
}

// The type of data that will be sent for a given
// element.
public enum ElementDataType: Int {
    
    case Int
    case Float
    case String
    case Archive // This may be a general purpose mechanism at some point - is currently used for deviceInfo
    
}

// The whole population of system and standard elements

public enum ElementType: Int {
    
    case DeviceInfoElement
    case SystemMessage
    case PlayerIndex
    
    // .Standard elements
    case PauseButton
    case LeftShoulder
    case RightShoulder
    case DpadXAxis
    case DpadYAxis
    case ButtonA
    case ButtonB
    case ButtonX
    case ButtonY
    case LeftThumbstickXAxis
    case LeftThumbstickYAxis
    case RightThumbstickXAxis
    case RightThumbstickYAxis
    case LeftTrigger
    case RightTrigger
    
    // Motion elements
    case MotionUserAccelerationX
    case MotionUserAccelerationY
    case MotionUserAccelerationZ
    
    case MotionAttitudeX
    case MotionAttitudeY
    case MotionAttitudeZ
    case MotionAttitudeW
    
    case MotionRotationRateX
    case MotionRotationRateY
    case MotionRotationRateZ
    
    case MotionGravityX
    case MotionGravityY
    case MotionGravityZ
    
    // Pedometer
    
    case ActivityType
    case ActivitySteps
    case ActivityDistance
    case ActivityFloors
    case ActivityPace
    case ActivityCadence
    
    // Custom
    //case Keyboard
    case Custom
    
}

///
/// Element is a class that represents each element/control on a controller, such as Button A or dpad.
/// Along with describing the controller element in terms of name and data type,and providing a
/// unique identifier used when transmitting values, an element functions as the backing store that
/// allows for multiple profiles to share the same underlying data set.  For example, because the Gamepad
/// profile is a subset of the Extended Gamepad, the element provides the basis for providing access to
/// values through both profile interfaces for the same controller.
///
/// - parameter type: ElementType enumerates the standard set of controller elements, plus a few system-
/// related elements, DeviceInfoElement, SystemMessage and Custom.
/// - parameter dataType: Currently three data types are supported, .String, .Int, and .Float, enumerated
/// in ElementDataType.
/// - parameter name: Human-readable name for the element.
/// - parameter value: The canonical value for the element.
/// - parameter getterKeypath: Path to the VgcController class interface for getting the value of the element.
/// - parameter setterKeypath: Path to the VgcController class interface for triggering the developer-defined
/// handlers for the element.
/// - parameter identifier: A unique integer indentifier used to identify the element a value belongs to
/// when transmitting the value over the network.
/// - parameter mappingComplete: A state management value used as a part of the peripheral-side element mapping system.
///
public class Element: NSObject {
    
    public var type: ElementType
    public var dataType: ElementDataType
    
    public var name: String
    public var value: AnyObject
    public var getterKeypath: String
    public var setterKeypath: String
    
    // Unique identifier is based on the element type
    public var identifier: Int!
    
    // Used only for custom elements
    #if !os(watchOS)
    public typealias VgcCustomElementValueChangedHandler = (VgcController, Element) -> Void
    public var valueChangedHandler: VgcCustomElementValueChangedHandler!
    #endif
    
    // Used as a flag when peripheral-side mapping one element to another, to prevent recursion
    var mappingComplete: Bool!
    
    #if os(iOS) || os(OSX) || os(tvOS)
    
    // Make class hashable - function to make it equatable appears below outside the class definition
    public override var hashValue: Int {
        return type.hashValue
    }
    #endif
    
    // Init for a standard (not custom) element
    public init(type: ElementType, dataType: ElementDataType,  name: String, getterKeypath: String, setterKeypath: String) {
        
        self.type = type
        self.dataType = dataType
        self.name = name
        self.value = Float(0.0)
        self.mappingComplete = false
        self.getterKeypath = getterKeypath
        self.setterKeypath = setterKeypath
        self.identifier = type.rawValue
        
        super.init()
    }
    
    #if os(iOS) || os(OSX) || os(tvOS)
    
    // Provides calculated keypaths for access to game controller elements
    
    public func getterKeypath(controller: VgcController) -> String {
        
        switch (type) {
            
        case .SystemMessage, .PlayerIndex, .PauseButton, .DeviceInfoElement: return ""
            
        case .MotionAttitudeX, .MotionAttitudeW, .MotionAttitudeY, .MotionAttitudeZ, .MotionGravityX, .MotionGravityY, .MotionGravityZ, .MotionRotationRateX, .MotionRotationRateY, .MotionRotationRateZ, .MotionUserAccelerationX, .MotionUserAccelerationY, .MotionUserAccelerationZ:
            
            return "motion." + getterKeypath
            
        default: return controller.profileType.pathComponentRead + "." + getterKeypath
        }
        
    }
    public func setterKeypath(controller: VgcController) -> String {
        
        switch (type) {
        case .SystemMessage, .PlayerIndex, .DeviceInfoElement: return ""
        case .MotionAttitudeX, .MotionAttitudeW, .MotionAttitudeY, .MotionAttitudeZ, .MotionGravityX, .MotionGravityY, .MotionGravityZ, .MotionRotationRateX, .MotionRotationRateY, .MotionRotationRateZ, .MotionUserAccelerationX, .MotionUserAccelerationY, .MotionUserAccelerationZ:
            
            return "motion." + setterKeypath
        default: return controller.profileType.pathComponentWrite + "." + setterKeypath
        }
    }
    
    required convenience public init(coder decoder: NSCoder) {
        
        let type = ElementType(rawValue: decoder.decodeIntegerForKey("type"))!
        let dataType = ElementDataType(rawValue: decoder.decodeIntegerForKey("type"))!
        let name = decoder.decodeObjectForKey("name") as! String
        let getterKeypath = decoder.decodeObjectForKey("getterKeypath") as! String
        let setterKeypath = decoder.decodeObjectForKey("setterKeypath") as! String
        
        self.init(type: type, dataType: dataType,  name: name, getterKeypath: getterKeypath, setterKeypath: setterKeypath)
        
    }
    
    public func encodeWithCoder(coder: NSCoder) {
        
        coder.encodeInteger(type.rawValue, forKey: "type")
        coder.encodeInteger(dataType.rawValue, forKey: "dataType")
        coder.encodeObject(name, forKey: "name")
        coder.encodeObject(getterKeypath, forKey: "getterKeypath")
        coder.encodeObject(setterKeypath, forKey: "setterKeypath")
        
    }
    
    func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = Element(type: type, dataType: dataType,  name: name, getterKeypath: getterKeypath, setterKeypath: setterKeypath)
        return copy
    }
    
    #endif
}

#if os(iOS) || os(OSX) || os(tvOS)
    // Make class equatable
    func ==(lhs: Element, rhs: Element) -> Bool {
        return lhs.type.hashValue == rhs.type.hashValue
    }
#endif

///
/// The Elements class describes the full population of controller controls, as well as
/// providing definitions of the population of elements for each profile type.
///
public class Elements: NSObject {
    
    override init() {
        
        systemElements = []
        systemElements.append(systemMessage)
        systemElements.append(deviceInfoElement)
        systemElements.append(pauseButton)
        
        motionProfileElements = []
        motionProfileElements.append(motionUserAccelerationX)
        motionProfileElements.append(motionUserAccelerationY)
        motionProfileElements.append(motionUserAccelerationZ)
        motionProfileElements.append(motionRotationRateX)
        motionProfileElements.append(motionRotationRateY)
        motionProfileElements.append(motionRotationRateZ)
        motionProfileElements.append(motionAttitudeX)
        motionProfileElements.append(motionAttitudeY)
        motionProfileElements.append(motionAttitudeZ)
        motionProfileElements.append(motionAttitudeW)
        motionProfileElements.append(motionGravityX)
        motionProfileElements.append(motionGravityY)
        motionProfileElements.append(motionGravityZ)
        
        
        // MicroGamepad profile element collection
        microGamepadProfileElements = []
        microGamepadProfileElements.append(pauseButton)
        microGamepadProfileElements.append(playerIndex)
        microGamepadProfileElements.append(dpadXAxis)
        microGamepadProfileElements.append(dpadYAxis)
        microGamepadProfileElements.append(buttonA)
        microGamepadProfileElements.append(buttonX)
        
        
        // Gamepad profile element collection
        gamepadProfileElements = []
        gamepadProfileElements.append(pauseButton)
        gamepadProfileElements.append(playerIndex)
        gamepadProfileElements.append(leftShoulder)
        gamepadProfileElements.append(rightShoulder)
        gamepadProfileElements.append(dpadXAxis)
        gamepadProfileElements.append(dpadYAxis)
        gamepadProfileElements.append(buttonA)
        gamepadProfileElements.append(buttonB)
        gamepadProfileElements.append(buttonX)
        gamepadProfileElements.append(buttonY)
        
        /*
        gamepadProfileElements.append(activityType)
        gamepadProfileElements.append(activitySteps)
        gamepadProfileElements.append(activityDistance)
        gamepadProfileElements.append(activityFloors)
        gamepadProfileElements.append(activityPace)
        gamepadProfileElements.append(activityCadence)
        */
        
        // Extended profile element collection
        extendedGamepadProfileElements = []
        extendedGamepadProfileElements.append(pauseButton)
        extendedGamepadProfileElements.append(playerIndex)
        extendedGamepadProfileElements.append(leftShoulder)
        extendedGamepadProfileElements.append(rightShoulder)
        extendedGamepadProfileElements.append(rightTrigger)
        extendedGamepadProfileElements.append(leftTrigger)
        extendedGamepadProfileElements.append(dpadXAxis)
        extendedGamepadProfileElements.append(dpadYAxis)
        extendedGamepadProfileElements.append(buttonA)
        extendedGamepadProfileElements.append(buttonB)
        extendedGamepadProfileElements.append(buttonX)
        extendedGamepadProfileElements.append(buttonY)
        extendedGamepadProfileElements.append(leftThumbstickXAxis)
        extendedGamepadProfileElements.append(leftThumbstickYAxis)
        extendedGamepadProfileElements.append(rightThumbstickXAxis)
        extendedGamepadProfileElements.append(rightThumbstickYAxis)
        
        // Watch profile element collection
        watchProfileElements = []
        watchProfileElements.append(pauseButton)
        watchProfileElements.append(playerIndex)
        watchProfileElements.append(leftShoulder)
        watchProfileElements.append(rightShoulder)
        watchProfileElements.append(rightTrigger)
        watchProfileElements.append(leftTrigger)
        watchProfileElements.append(dpadXAxis)
        watchProfileElements.append(dpadYAxis)
        watchProfileElements.append(buttonA)
        watchProfileElements.append(buttonB)
        watchProfileElements.append(buttonX)
        watchProfileElements.append(buttonY)
        watchProfileElements.append(leftThumbstickXAxis)
        watchProfileElements.append(leftThumbstickYAxis)
        watchProfileElements.append(rightThumbstickXAxis)
        watchProfileElements.append(rightThumbstickYAxis)
        
        /*
        
        extendedGamepadProfileElements.append(activityType)
        extendedGamepadProfileElements.append(activitySteps)
        extendedGamepadProfileElements.append(activityDistance)
        extendedGamepadProfileElements.append(activityFloors)
        extendedGamepadProfileElements.append(activityPace)
        extendedGamepadProfileElements.append(activityCadence)
        */
        
        // Iterate the set to set the identifier and load up the hash
        // used by devs to access the elements
        
        for customElement in Elements.customElements.customProfileElements {
            
            let elementCopy = customElement.copy() as! Element
            elementCopy.identifier = customElement.identifier
            custom[elementCopy.identifier] = elementCopy
        }
        
        customProfileElements = Elements.customElements.customProfileElements
        
        super.init()
        
        for element in systemElements {
            elementsByHashValue.updateValue(element, forKey: element.identifier)
        }
        
        // Create lookup for getting element based on hash value
        for element in allElementsCollection() {
            elementsByHashValue.updateValue(element, forKey: element.identifier)
        }
        
    }
    
    var systemElements: [Element]
    var extendedGamepadProfileElements: [Element]
    var gamepadProfileElements: [Element]
    var microGamepadProfileElements: [Element]
    var motionProfileElements: [Element]
    public var watchProfileElements: [Element]
    private var elementsByHashValue = Dictionary<Int, Element>()
    
    public static var customElements: CustomElementsSuperclass!
    public static var customMappings: CustomMappingsSuperclass!
    
    public var custom = Dictionary<Int, Element>()
    public var customProfileElements = [Element]()
    
    public func allElementsCollection() -> [Element] {
        
        let myAll = systemElements + extendedGamepadProfileElements + motionProfileElements + customProfileElements
        return myAll
        
    }
    
    #if !os(watchOS)
    public func elementsForController(controller: VgcController) -> [Element] {
        
        var supplemental: [Element] = []
        if controller.deviceInfo.supportsMotion { supplemental = motionProfileElements }
        
        // Get the controller-specific set of custom elements so they contain the
        // current values for the elements
        let customElements = controller.elements.custom.values
        //let customElements: [Element] = controller.custom.values
        supplemental = supplemental + customElements
        
        supplemental.insert(systemMessage, atIndex: 0)
        
        switch(controller.profileType) {
        case .MicroGamepad:
            return microGamepadProfileElements + supplemental
        case .Gamepad:
            return gamepadProfileElements + supplemental
        case .ExtendedGamepad:
            return extendedGamepadProfileElements + supplemental
        default:
            return extendedGamepadProfileElements + supplemental
        }
        
    }
    #endif
    
    public var systemMessage: Element = Element(type: .SystemMessage, dataType: .Int, name: "System Messages", getterKeypath: "", setterKeypath: "")
    public var deviceInfoElement: Element = Element(type: .DeviceInfoElement, dataType: .Archive, name: "Device Info", getterKeypath: "", setterKeypath: "")
    public var playerIndex: Element = Element(type: .PlayerIndex, dataType: .Int, name: "Player Index", getterKeypath: "playerIndex", setterKeypath: "playerIndex")
    public var pauseButton: Element = Element(type: .PauseButton, dataType: .Float, name: "Pause Button", getterKeypath: "vgcPauseButton", setterKeypath: "vgcPauseButton")
    
    public var leftShoulder: Element = Element(type: .LeftShoulder, dataType: .Float, name: "Left Shoulder", getterKeypath: "leftShoulder.value", setterKeypath: "leftShoulder.value")
    public var rightShoulder: Element = Element(type: .RightShoulder, dataType: .Float, name: "Right Shoulder", getterKeypath: "rightShoulder.value", setterKeypath: "rightShoulder.value")
    
    public var dpadXAxis: Element = Element(type: .DpadXAxis, dataType: .Float, name: "dpad X", getterKeypath: "dpad.xAxis.value", setterKeypath: "dpad.xAxis.value")
    public var dpadYAxis: Element = Element(type: .DpadYAxis, dataType: .Float, name: "dpad Y", getterKeypath: "dpad.yAxis.value", setterKeypath: "dpad.yAxis.value")
    
    public var buttonA: Element = Element(type: .ButtonA, dataType: .Float, name: "A", getterKeypath: "buttonA.value", setterKeypath: "buttonA.value")
    public var buttonB: Element = Element(type: .ButtonB, dataType: .Float, name: "B", getterKeypath: "buttonB.value", setterKeypath: "buttonB.value")
    public var buttonX: Element = Element(type: .ButtonX, dataType: .Float, name: "X", getterKeypath: "buttonX.value", setterKeypath: "buttonX.value")
    public var buttonY: Element = Element(type: .ButtonY, dataType: .Float, name: "Y", getterKeypath: "buttonY.value", setterKeypath: "buttonY.value")
    
    public var leftThumbstickXAxis: Element = Element(type: .LeftThumbstickXAxis, dataType: .Float, name: "Left Thumb X", getterKeypath: "leftThumbstick.xAxis.value", setterKeypath: "leftThumbstick.xAxis.value")
    public var leftThumbstickYAxis: Element = Element(type: .LeftThumbstickYAxis, dataType: .Float, name: "Left Thumb Y", getterKeypath: "leftThumbstick.yAxis.value", setterKeypath: "leftThumbstick.yAxis.value")
    public var rightThumbstickXAxis: Element = Element(type: .RightThumbstickXAxis, dataType: .Float, name: "Right Thumb X", getterKeypath: "rightThumbstick.xAxis.value", setterKeypath: "rightThumbstick.xAxis.value")
    public var rightThumbstickYAxis: Element = Element(type: .RightThumbstickYAxis, dataType: .Float, name: "Right Thumb Y", getterKeypath: "rightThumbstick.yAxis.value", setterKeypath: "rightThumbstick.yAxis.value")
    
    public var rightTrigger: Element = Element(type: .RightTrigger, dataType: .Float, name: "Right Trigger", getterKeypath: "rightTrigger.value", setterKeypath: "rightTrigger.value")
    public var leftTrigger: Element = Element(type: .LeftTrigger, dataType: .Float, name: "Left Trigger", getterKeypath: "leftTrigger.value", setterKeypath: "leftTrigger.value")
    
    public var motionUserAccelerationX: Element = Element(type: .MotionUserAccelerationX, dataType: .Float, name: "Accelerometer X", getterKeypath: "motionUserAccelerationX", setterKeypath: "motionUserAccelerationX")
    public var motionUserAccelerationY: Element = Element(type: .MotionUserAccelerationY, dataType: .Float, name: "Accelerometer Y", getterKeypath: "motionUserAccelerationY", setterKeypath: "motionUserAccelerationY")
    public var motionUserAccelerationZ: Element = Element(type: .MotionUserAccelerationZ, dataType: .Float, name: "Accelerometer Z", getterKeypath: "motionUserAccelerationZ", setterKeypath: "motionUserAccelerationZ")
    
    public var motionRotationRateX: Element = Element(type: .MotionRotationRateX, dataType: .Float, name: "Rotation Rate X", getterKeypath: "motionRotationRateX", setterKeypath: "motionRotationRateX")
    public var motionRotationRateY: Element = Element(type: .MotionRotationRateY, dataType: .Float, name: "Rotation Rate Y", getterKeypath: "motionRotationRateY", setterKeypath: "motionRotationRateY")
    public var motionRotationRateZ: Element = Element(type: .MotionRotationRateZ, dataType: .Float, name: "Rotation Rate Z", getterKeypath: "motionRotationRateZ", setterKeypath: "motionRotationRateZ")
    
    public var motionGravityX: Element = Element(type: .MotionGravityX, dataType: .Float, name: "Gravity X", getterKeypath: "motionGravityX", setterKeypath: "motionGravityX")
    public var motionGravityY: Element = Element(type: .MotionGravityY, dataType: .Float, name: "Gravity Y", getterKeypath: "motionGravityY", setterKeypath: "motionGravityY")
    public var motionGravityZ: Element = Element(type: .MotionGravityZ, dataType: .Float, name: "Gravity Z", getterKeypath: "motionGravityZ", setterKeypath: "motionGravityZ")
    
    public var motionAttitudeX: Element = Element(type: .MotionAttitudeX, dataType: .Float, name: "Attitude X", getterKeypath: "motionAttitudeX", setterKeypath: "motionAttitudeX")
    public var motionAttitudeY: Element = Element(type: .MotionAttitudeY, dataType: .Float, name: "Attitude Y", getterKeypath: "motionAttitudeY", setterKeypath: "motionAttitudeY")
    public var motionAttitudeZ: Element = Element(type: .MotionAttitudeZ, dataType: .Float, name: "Attitude Z", getterKeypath: "motionAttitudeZ", setterKeypath: "motionAttitudeZ")
    public var motionAttitudeW: Element = Element(type: .MotionAttitudeW, dataType: .Float, name: "Attitude W", getterKeypath: "motionAttitudeW", setterKeypath: "motionAttitudeW")
    
    public var activityType: Element = Element(type: .MotionAttitudeX, dataType: .Float, name: "Type", getterKeypath: "type", setterKeypath: "type")
    public var activitySteps: Element = Element(type: .MotionAttitudeY, dataType: .Float, name: "Steps", getterKeypath: "steps.value", setterKeypath: "steps.value")
    public var activityDistance: Element = Element(type: .MotionAttitudeZ, dataType: .Float, name: "Distance", getterKeypath: "distance.value", setterKeypath: "distance.value")
    public var activityFloors: Element = Element(type: .MotionAttitudeW, dataType: .Float, name: "Floors", getterKeypath: "floors.value", setterKeypath: "floors.value")
    public var activityPace: Element = Element(type: .MotionAttitudeX, dataType: .Float, name: "Pace", getterKeypath: "pace.value", setterKeypath: "pace.value")
    public var activityCadence: Element = Element(type: .MotionAttitudeY, dataType: .Float, name: "Cadence", getterKeypath: "cadence.value", setterKeypath: "cadence.value")
    
    // Convience functions for getting a controller element object based on specific properties of the
    // controller element

    
    public func elementFromType(type: ElementType) -> Element! {
        
        for element in allElementsCollection() {
            if element.type == type { return element }
        }
        return nil
    }
    
    public func elementFromIdentifier(identifier: Int) -> Element! {
        
        guard let element = elementsByHashValue[identifier] else { return nil }
        return element
    }
    
}

// Convienance initializer, simplifies creation of custom elements
public class CustomElement: Element {
    
    // Init for a custom element
    public init(name: String, dataType: ElementDataType, type: Int) {
        
        super.init(type: .Custom , dataType: dataType, name: name, getterKeypath: "", setterKeypath: "")
        
        identifier = type
        
    }
    
    required convenience public init(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

// A stub, to support creation of a custom mappings class external to a framework
public class CustomMappingsSuperclass: NSObject {
    
    public var mappings = Dictionary<Int, Int>()
    public override init() {
        
        super.init()
        
    }
    
}

// A stub, to support creation of a custom elements class external to a framework
public class CustomElementsSuperclass: NSObject {
    
    // Custom profile-level handler
    // Watch OS implementation does not include VgcController because it does not support parent class GCController
    #if !os(watchOS)
    public typealias VgcCustomProfileValueChangedHandler = (VgcController, Element) -> Void
    public var valueChangedHandler: VgcCustomProfileValueChangedHandler!
    #endif
    
    public var customProfileElements: [Element] = []
    
    public override init() {
        
        super.init()
    }
    
}