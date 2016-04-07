//
//  VgcManager.swift
//  
//
//  Created by Rob Reuss on 10/8/15.
//
//

import Foundation
#if !(os(watchOS))
import GameController
#endif
#if os(iOS) || os(tvOS) // Need this only for UIDevice
    import UIKit
#endif
#if os(watchOS)
    import WatchKit
#endif

/// The "elements" global should be considered private from the Central development side of things.
/// In that context, it provides the backing state of the software controller for
/// the various profiles, and should not be accessed directly.  
/// 
/// On the peripheral development side, it is a key part of developing a custom software-based
/// peripheral, providing the basis for sending element values to the Central.
///
/// This variable provides a reference to an Elements object that acts as an
/// an interface to both standard and custom elements, provides a couple of methods
/// for access those sets, and provides access to individual Element instances for
/// each supported element.  
///

public var customElements: CustomElementsSuperclass!

///
/// appRole:
/// The appRole value must ONLY be set by passing it as a parameter to startAs.
///
/// - parameter .Central:           The consumer of the Peripheral data, typically a game.
///
/// - parameter .Peripheral:        A game controller that may be a hardware controller or a
///                                 VGC software controller, it receives input from a user through
///                                 Elements (buttons, thumbsticks, accelerometer, etc.) and sends
///                                 those values to either a Bridge or a Central.
///
/// - parameter .Bridge:            An intermediary between Peripherals and the Central, which
///                                 effectively functions as both a Central and Peripheral, usually
///                                 forwarding element values to the Central, although it may also
///                                 process those values in terms of calling handlers. An iPhone
///                                 positioned in a slide-on controller will typically function as
///                                 as a Bridge (although it can also be a Central).  An iPhone paired
///                                 with an Apple Watch that is functioning as a Peripheral will act
///                                 as a Bridge.  
///
/// - parameter .EnhancementBridge:  Special Bridge mode for using a form-fitting/slide-on controller
///                                 with an iPhone.  Prevents additional Peripherals from connecting.
///
@objc public enum AppRole: Int, CustomStringConvertible {
    
    case Central = 0
    case Peripheral = 1
    case Bridge = 2
    case EnhancementBridge = 3
    
    public var description : String {
        switch self {
        case .Central: return "Central"
        case .Peripheral: return "Peripheral"
        case .Bridge: return "Bridge"
        case .EnhancementBridge: return "Enhancement Bridge"
        }
    }
}

///
/// ControllerType enumeration: Most values are for informational purposes,
/// except MFiHardware, which is used to trigger the "wrapped" approach to
/// handling hardware controllers in VgcController.
///

@objc public enum ControllerType: Int, CustomStringConvertible {
    case Software
    case MFiHardware
    case ICadeHardware
    case BridgedMFiHardware
    case BridgedICadeHardware
    case Watch
    
    public var description : String {
        switch self {
        case .MFiHardware: return "MFi Hardware"
        case .ICadeHardware: return "iCade Hardware"
        case .Software: return "Software"
        case .BridgedMFiHardware: return "Bridged MFi Hardware"
        case .BridgedICadeHardware: return "Bridged iCade Hardware"
        case .Watch: return "Watch"
        }
    }
}

@objc public enum ProfileType: Int, CustomStringConvertible {
    
    case Unknown
    case GenericGamepad
    case MicroGamepad
    case Gamepad
    case ExtendedGamepad
    case Motion
    case Watch
    
    public var description : String {
        switch self {
        case .Unknown: return "Unknown"
        case .GenericGamepad: return "GenericGamepad"
        case .MicroGamepad: return "MicroGamepad"
        case .Gamepad: return "Gamepad"
        case .ExtendedGamepad: return "ExtendedGamepad"
        case .Motion: return "Motion"
        case .Watch: return "Watch"
        }
    }
    
    var pathComponentRead : String {
        switch self {
        case .Unknown: return ""
        case .GenericGamepad: return ""
        case .MicroGamepad: return "microGamepad"
        case .Gamepad: return "gamepad"
        case .ExtendedGamepad: return "extendedGamepad"
        case .Motion: return "motion"
        case .Watch: return "extendedGamepad"
        }
    }
    
    var pathComponentWrite : String {
        switch self {
        case .Unknown: return ""
        case .GenericGamepad: return ""
        case .MicroGamepad: return "vgcMicroGamepad"
        case .Gamepad: return "vgcGamepad"
        case .ExtendedGamepad: return "vgcExtendedGamepad"
        case .Motion: return "vgcMotion"
        case .Watch: return "vgcExtendedGamepad"
        }
    }
    
}

/// For transmitted element value messages...
let messageValueSeperator = ":"

#if !os(watchOS)
@objc public class VgcService: NSObject {
    
    public var name: String
    public var type: AppRole
    internal var netService: NSNetService
    
    public var fullName: String { return "\(name) (\(type.description))" }
    
    init(name: String, type: AppRole, netService: NSNetService) {
        self.name = name
        self.type = type
        self.netService = netService
    }
}
#endif

public class VgcManager: NSObject {
   
    // Define this as a singleton although never used as such; only class methods used
    static let sharedInstance = VgcManager()
    private override init() {}

    // Default to being a Peripheral
    public static var appRole: AppRole = .Peripheral
    
    #if !os(watchOS)
    /// Used by the Central to configure a software controller, in terms of profile type, background
    /// color and such
    public static var peripheralSetup = VgcPeripheralSetup()
    #endif
    
    ///
    /// Shared set of elements (in contrast to controllers on a Central/Bridge, each
    /// of which have their own set of elements).
    ///
    public static var elements = Elements()
    
    /// Log Level "Debug" is a standard level of logging for debugging - set to "Error" for release
    @objc public static var loggerLogLevel: LogLevel = LogLevel.Debug {
        didSet {
            vgcLogDebug("Set logLevel: \(VgcManager.loggerLogLevel)")
        }
    }
    
    /// Use either NSLog or Swift "print" for logging - NSLog gives more detail
    @objc public static var loggerUseNSLog: Bool = false {
        didSet {
            vgcLogDebug("Set NSLog logging to: \(VgcManager.loggerUseNSLog)")
        }
    }
    
    ///
    /// Used as a component of the bonjour names for the various app types.
    /// This should be set to something that uniquely identifies your app.
    ///
    public static var appIdentifier = "vgc"
    
    static var bonjourTypeCentral: String { return "_\(VgcManager.appIdentifier)_central._tcp." }
    static var bonjourTypeBridge: String { return "_\(VgcManager.appIdentifier)_bridge._tcp." }
    
    ///
    /// An app in Bridge mode can call it's handlers or simply relay
    /// data forward to the Central.  Relaying is more performant.
    ///
    public static var bridgeRelayOnly = false

    #if !os(watchOS)
    ///
    /// The vendor of the iCade controller in use, or .Disabled if the functionality
    /// is not being used.  The Mode can be set at any time, and would presumably be
    /// in response to an end-user selecting the type of iCade controller they've paired
    /// with their iOS device.
    ///
    public static var iCadeControllerMode: IcadeControllerMode = .Disabled {

        didSet {
            
            #if !os(watchOS)
            if iCadeControllerMode != .Disabled { iCadePeripheral = VgcIcadePeripheral() } else { iCadePeripheral = nil }
            #endif
            
        }
    }

    public static var iCadePeripheral: VgcIcadePeripheral!
    #endif
    
    ///
    /// We support mapping from either the Peripheral or Central side.  Central-side mapping
    /// is recommended; it is more efficient because two values do not need to be transmitted.
    /// Central-side mapping also works with hardware controllers.
    ///
    public static var usePeripheralSideMapping: Bool = false

    public static var netServiceBufferSize = 2048
    
    public static var netServiceLatencyLogging = false
    
    // The header length of messages
    static var netServiceHeaderLength: Int {
        
        get {
            if VgcManager.netServiceLatencyLogging {
                return 17
            } else {
                return 9
            }
        }
        
    }
    
    // Indicator of start of header
    static var headerIdentifier: UInt32 = 2584594329 // Random UInt32
    
    // Maximum time to wait for both the small and large data streams to be opened, in seconds
    static var maxTimeForMatchingStreams = 5.0
    
    // Disabling peer-to-peer (provides Bluetooth fallback) may improve performance if needed
    // NOTE: This property cannot be set after startAs is called.  Instead, use the version of
    // startAs that includes the includesPeerToPeer parameter.
    public static var includesPeerToPeer = false
    
    ///
    /// Logs measurements of mesages transmitted/received and displays in console
    ///
    static var performanceSamplingEnabled: Bool { get { return performanceSamplingDisplayFrequency > 0 } }
    
    ///
    /// Controls how long we wait before averaging the number of messages
    /// transmitted/received per second when logging performance.  Set to 0 to disable.
    ///
    public static var performanceSamplingDisplayFrequency: Float = 10.0

    #if !os(watchOS)
    public static var peripheral: Peripheral!
    #endif
    
    /// Network name for publishing service, defaults to device name
    #if !os(watchOS) && !os(OSX)
    public static var centralServiceName = UIDevice.currentDevice().name
    #endif
    #if os(OSX)
    public static var centralServiceName = NSHost.currentHost().localizedName
    #endif

    #if !os(watchOS)
    public class func publishCentralService() {
        if appRole == .Central {
            VgcController.centralPublisher.publishService()
        } else {
            vgcLogError("Refused to publish Central service because appRole is not Central")
        }
    }
    
    public class func unpublishCentralService() {
        if appRole == .Central {
            VgcController.centralPublisher.unpublishService()
        } else {
            vgcLogError("Refused to unpublish Central service because appRole is not Central")
        }
    }
    #endif
    
    /// Simplified version of startAs when custom mapping and custom elements are not needed
    public class func startAs(appRole: AppRole, appIdentifier: String) {
        VgcManager.startAs(appRole, appIdentifier: appIdentifier, customElements: CustomElementsSuperclass(), customMappings: CustomMappingsSuperclass())
    }
    
    /// Simplified version of startAs when custom mapping and custom elements are not needed, but includesPeerToPeer is
    public class func startAs(appRole: AppRole, appIdentifier: String, includesPeerToPeer: Bool) {
        VgcManager.startAs(appRole, appIdentifier: appIdentifier, customElements: CustomElementsSuperclass(), customMappings: CustomMappingsSuperclass(), includesPeerToPeer: includesPeerToPeer)
    }
    
    /// Must use this startAs method to turn on peer to peer functionality (Bluetooth)
    public class func startAs(appRole: AppRole, appIdentifier: String, customElements: CustomElementsSuperclass!, customMappings: CustomMappingsSuperclass!, includesPeerToPeer: Bool) {
        VgcManager.includesPeerToPeer = includesPeerToPeer
        startAs(appRole, appIdentifier: appIdentifier, customElements: customElements, customMappings: customMappings)
    }
    
    ///
    /// Kicks off the search for software controllers.  This is a required method and should be
    /// called early in the application launch process.
    ///
    public class func startAs(appRole: AppRole, appIdentifier: String, customElements: CustomElementsSuperclass!, customMappings: CustomMappingsSuperclass!) {
        
        self.appRole = appRole
        
        if appIdentifier != "" { self.appIdentifier = appIdentifier } else { vgcLogError("You must set appIdentifier to some string") }
        
        Elements.customElements = customElements
        Elements.customMappings = customMappings
        
        vgcLogDebug("Setting up as a \(VgcManager.appRole.description.uppercaseString)")
        vgcLogDebug("IncludesPeerToPeer is set to: \(VgcManager.includesPeerToPeer)")

        #if !os(watchOS)
            
        switch (VgcManager.appRole) {
            
            case .Peripheral:
                
                VgcManager.peripheral = Peripheral()
                
                // Default device for software Peripheral, can be overriden by setting the VgcManager.peripheral.deviceInfo property
                VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
            
                #if os(iOS)
                    VgcManager.peripheral.watch = VgcWatch(delegate: VgcManager.peripheral)
                #endif
            
            case .Central:
                VgcController.setup()
            
            case .Bridge, .EnhancementBridge:
                
                VgcController.setup()
            }
      
        #endif

    }
    
}

// Convienance function
public func deviceIsTypeOfBridge() -> Bool {
    return VgcManager.appRole == .Bridge || VgcManager.appRole == .EnhancementBridge
}

// Meta information related to the controller.  This object is
// made available for both hardware and software controllers.  It
// supports copying, for use in the bridge/forwarding context, and
// supports archiving for transmission from peripheral to central.

/// DeviceInfo contains key properties of a controller, either hardware or software.  
/// 
/// - parameter deviceUID: Unique identifier for the controller.  Hardware controllers have this built-in.  An arbitrary identifier can be given to a software controller, and the NSUUID().UUIDString function is recommended.
///
/// - parameter vendorName: Built-in to a hardware controller.  For software controllers, either define a name or use an empty string "" and the machine/device name will be used.
///
/// - parameter profileType: Built-in to a hardware controller.  This can be aribtrarily set to either extendedGamepad or Gamepad for a software controller, and will determine what elements are available to the controller.  microGamepad is only available in the tvOS context and is untested with software controllers.
///
/// - parameter supportsMotion: Built-in parameter with a hardware controller (the Apple TV remote is the only hardware controller known to support motion). This can be set when defining a software controller, but would be overriden on the basis of the availabiity of Core Motion.  For example, an OSX-based software controller would report supports motion as false.
///

@objc public class DeviceInfo: NSObject, NSCoding {
    
    internal(set) var deviceUID: String
    internal(set) public var vendorName: String
    internal(set) public var attachedToDevice: Bool
    public var profileType: ProfileType
    internal(set) public var controllerType: ControllerType
    internal(set) public var supportsMotion: Bool
    
    @objc public init(var deviceUID: String, vendorName: String, attachedToDevice: Bool, profileType: ProfileType, controllerType: ControllerType, supportsMotion: Bool) {
        
        // If no deviceUID is specified, auto-generate a UID and store it to provide
        // a persistent way of identifying the peripheral.
        if deviceUID == "" {
            let defaults = NSUserDefaults.standardUserDefaults()
            if let existingDeviceUID = defaults.stringForKey("deviceUID") {
                vgcLogDebug("Found existing UID for device: \(existingDeviceUID)")
                deviceUID = existingDeviceUID
            } else {
                deviceUID = NSUUID().UUIDString
                vgcLogDebug("Created new UID for device: \(deviceUID)")
                defaults.setObject(deviceUID, forKey: "deviceUID")
            }
        }
        
        self.deviceUID = deviceUID
        self.attachedToDevice = attachedToDevice
        self.profileType = profileType
        self.controllerType = controllerType
        self.supportsMotion = supportsMotion
        self.vendorName = vendorName
        
        super.init()
        
        if (self.vendorName == "") {
            #if os(iOS) || os(tvOS)
                self.vendorName = UIDevice.currentDevice().name
            #endif
            #if os(OSX)
                self.vendorName = NSHost.currentHost().localizedName!
            #endif
            #if os(watchOS)
                self.vendorName = WKInterfaceDevice.currentDevice().name
            #endif
        }
        if self.vendorName == "" {
            self.vendorName = "Unknown"
        }
        
        if profileType == .MicroGamepad {
            vgcLogError("The use of the .MicroGamepad profile for software-based controllers will lead to unpredictable results.")
        }
        
    }
    
    public override var description: String {
        
        var result: String = "\n"
        result += "Device information:\n\n"
        result += "Vendor:    \(self.vendorName)\n"
        result += "Type:      \(self.controllerType)\n"
        result += "Profile:   \(self.profileType)\n"
        result += "Attached:  \(self.attachedToDevice)\n"
        result += "Motion:    \(self.supportsMotion)\n"
        result += "ID:        \(self.deviceUID)\n"
        return result
        
    }
    
    // The deviceInfo is sent over-the-wire to a Bridge or Central using
    // NSKeyed archiving...
    
    required convenience public init(coder decoder: NSCoder) {
        
        let deviceUID = decoder.decodeObjectForKey("deviceUID") as! String
        let vendorName = decoder.decodeObjectForKey("vendorName") as! String
        let attachedToDevice = decoder.decodeBoolForKey("attachedToDevice")
        let profileType = ProfileType(rawValue: decoder.decodeIntegerForKey("profileType"))
        let supportsMotion = decoder.decodeBoolForKey("supportsMotion")
        let controllerType = ControllerType(rawValue: decoder.decodeIntegerForKey("controllerType"))
        
        self.init(deviceUID: deviceUID, vendorName: vendorName, attachedToDevice: attachedToDevice, profileType: profileType!, controllerType: controllerType!, supportsMotion: supportsMotion)
        
    }
    
    public func encodeWithCoder(coder: NSCoder) {
        
        coder.encodeObject(self.deviceUID, forKey: "deviceUID")
        coder.encodeObject(self.vendorName, forKey: "vendorName")
        coder.encodeBool(self.attachedToDevice, forKey: "attachedToDevice")
        coder.encodeInteger(self.profileType.rawValue, forKey: "profileType")
        coder.encodeInteger(self.controllerType.rawValue, forKey: "controllerType")
        coder.encodeBool(self.supportsMotion, forKey: "supportsMotion")
        
    }
    
    // A copy of the deviceInfo object is made when forwarding it through a Bridge.
    func copyWithZone(zone: NSZone) -> AnyObject {
        let copy = DeviceInfo(deviceUID: deviceUID, vendorName: vendorName, attachedToDevice: attachedToDevice, profileType: profileType, controllerType: controllerType, supportsMotion: supportsMotion)
        return copy
    }
    
}