//
//  VirtualGameControllerPeripheral.swift
//  PeripheralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//
//  Testing git

import Foundation

// No CoreBluetooth or GameController on WatchOS
#if os(iOS) || os(OSX) || os(tvOS)
    import CoreBluetooth
    import GameController
#endif

#if os(iOS)
    import UIKit
#endif

public let VgcPeripheralDidConnectNotification:     String = "VgcPeripheralDidConnectNotification"
public let VgcPeripheralDidDisconnectNotification:  String = "VgcPeripheralDidDisconnectNotification"
public let VgcPeripheralFoundService:               String = "VgcPeripheralFoundService"
public let VgcPeripheralLostService:                String = "VgcPeripheralLostService"
public let VgcPeripheralDidResetBrowser:            String = "VgcPeripheralDidResetBrowser"
public let VgcSystemMessageNotification:            String = "VgcSystemMessageNotification"
public let VgcNewPlayerIndexNotification:           String = "VgcNewPlayerIndexNotification"

public class Peripheral: NSObject {
    
    private var vgcDeviceInfo: DeviceInfo!
    var browser: VgcBrowser!
    var playerIndex: GCControllerPlayerIndex!
    weak var controller: VgcController!
    
    #if !(os(tvOS)) && !(os(OSX))
    public var motion: VgcMotionManager!
    #endif

    public var haveConnectionToCentral: Bool?
    
    override init() {
        
        super.init()

        self.haveConnectionToCentral = false
        
        #if !os(watchOS)
            browser = VgcBrowser(peripheral: self)
        #endif
        
        print("Setting up motion manager on peripheral")
        #if !os(OSX) && !os(tvOS)
        self.motion = VgcMotionManager()
        #endif
        
        playerIndex = GCControllerPlayerIndex.IndexUnset
         
    }
    
    deinit {
        print("Peripheral deinitalized")
        if controller != nil { controller.peripheral = nil }
        controller = nil
    }
    
    ///
    /// Key method used to send a change in an element's state to the
    /// Central or Bridge that we're currently connected to with this
    /// Peripheral.  "State" in this case refers to the Element "value"
    /// property.
    ///
    public func sendElementState(element: Element) {
        
        // As a Peripheral, we don't need a connection to send if we're an EnhancementBridge, using instead the
        // stream associated with the hardware controllers VgcController.
        if self.haveConnectionToCentral == true || VgcManager.appRole == .EnhancementBridge {
            
            //print("Sending: \(element.name): \(element.value)")
            
            // If we're enhancing a hardware controller with virtual elements, we pass values through to the controller
            // so they appear to the Central as coming from the hardware controller
            if VgcManager.appRole == .EnhancementBridge && VgcController.enhancedController != nil {
                VgcController.enhancedController.peripheral.browser.sendElementStateOverNetService(element)
            } else {
                browser.sendElementStateOverNetService(element)
            }
            
            //print("Element to be mapped: \(element.name)")
            if VgcManager.usePeripheralSideMapping == true {
                // Only map an element if it isn't the result of a mapping
                if (element.mappingComplete == false) {
                    mapElement(element, peripheral: self)
                }
            }
            
            element.mappingComplete = false
            
        } else {
            
            print("ERROR: Attempted to send without a connection: \(element.name): \(element.value)")
            
        }
        
    }
    
    ///
    /// DeviceInfo for the controller represented by this Peripheral instance.
    ///
    public var deviceInfo: DeviceInfo! {
        
        get {
            if self.vgcDeviceInfo == nil {
                print("ERROR: Required value deviceInfo not set")
                return nil
            }
            return self.vgcDeviceInfo
        }
        
        set {
            
            self.vgcDeviceInfo = newValue
            
            #if os(iOS)

                motion.deviceSupportsMotion = deviceInfo.supportsMotion
                
                // Override device info parameter if the hardware doesn't support motion
                if motion.manager.deviceMotionAvailable == false { deviceInfo.supportsMotion = false } else { deviceInfo.supportsMotion = true }
                
            #endif
            
            self.haveConnectionToCentral = false
            
            if !(deviceIsTypeOfBridge()) { self.browseForServices() }  // Let the Central know we exist, but put it off if we are a bridge
            
        }
        
    }
    
    ///
    /// Connect to a Central or Bridge using a VgcService object obtained
    /// by browsing the network.
    ///
    public func connectToService(vgcService: VgcService) {
        browser.connectToService(vgcService)
    }
    
    public func disconnectFromService() {
        
        if self.haveConnectionToCentral == false { return }
        
        print("Disconnecting from Central")
        
        self.haveConnectionToCentral = false
        
        browser.disconnectFromCentral()
        
    }
    
    public func browseForServices() {
        
        browser.reset()
        
        print("Browsing for services...")
        
        NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralDidResetBrowser, object: nil)
        
        // If we're a bridge, this peripheral is a controller-specific instance.  If the controller is no
        // longer in the array of controllers, it means it has disconnected and we don't want to advertise it
        // any longer.
        if deviceIsTypeOfBridge() {
            let (existsAlready, _) = VgcController.controllerAlreadyExists(self.controller)
            if existsAlready == false {
                print("Refusing to announce Bridge-to-Central peripheral because it's controller no longer exists.  If the controller is MFi, it may have gone to sleep.")
                return
            }
        }
        
        browser.browseForCentral()
        
    }
    
    public func stopBrowsingForServices() {
        
        if deviceIsTypeOfBridge() {
            print("Refusing to stop browsing for service because I am a BRIDGE")
        } else {
            print("Stopping browsing for services")
        }
        browser.stopBrowsing()
        
    }
    
    public var availableServices: [VgcService] {
        get {
            let services = [VgcService](browser.serviceLookup.values)
            return services
        }
    }
    
    func gotConnectionToCentral() {
        
        print("In peripheral mode gotConnection (have connection already: \(self.haveConnectionToCentral)")
        
        if (self.haveConnectionToCentral == true) { return }
        
        NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralDidConnectNotification, object: nil)
        
        self.haveConnectionToCentral = true
        
        if deviceIsTypeOfBridge() {
            
            self.bridgePeripheralDeviceInfoToCentral(controller)
            
        } else {
            
            self.sendDeviceInfo(self.deviceInfo)
            
        }
        
    }
    
    func lostConnectionToCentral(vgcService: VgcService) {
        
        print("Peripheral lost connection to Central")
        self.haveConnectionToCentral = false
        
        NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralDidDisconnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralLostService, object: vgcService)
        
        // Start browsing for a new Central only if the controller still exists (that is, if it
        // hasn't disconnected.  Otherwise, we might create a "ghost" controller on the Central.
        if deviceIsTypeOfBridge() == false || VgcController.controllers().contains(controller) { browser.browseForCentral() }
        /*
        // A bit of a delay to clear the browser caches
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(3.0 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
        self.browseForServices()
        }
        */
        
        #if !(os(tvOS))  && !(os(OSX))
            if !deviceIsTypeOfBridge() {
                print("Stopping motion data")
                motion.stop()
            }
        #endif
        
    }
    
    func sendDeviceInfo(deviceInfo: DeviceInfo) {
        
        if (self.haveConnectionToCentral == false) {
            print("No connection to Central so not sending controller device info")
            return
        }
        
        print("Sending device info for controller \(deviceInfo.vendorName) to Central")
        
        NSKeyedArchiver.setClassName("DeviceInfo", forClass: DeviceInfo.self)
        let archivedDeviceInfoData = NSKeyedArchiver.archivedDataWithRootObject(deviceInfo)
        let archivedDeviceInfoBase64String = archivedDeviceInfoData.base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        print("Device info: \(deviceInfo)")
        
        self.browser.sendArchivedDeviceInfo(archivedDeviceInfoBase64String)

    }
    
    func bridgePeripheralDeviceInfoToCentral(controller: VgcController) {
        
        print("Forwarding controller \(controller.deviceInfo.vendorName) to Central")
        
        let deviceInfo = controller.deviceInfo.copy() as! DeviceInfo
        deviceInfo.vendorName = deviceInfo.vendorName + " (Bridged)"
        if deviceInfo.controllerType == .MFiHardware { deviceInfo.controllerType = .BridgedMFiHardware }
        if deviceInfo.controllerType == .ICadeHardware { deviceInfo.controllerType = .BridgedICadeHardware }
        if deviceInfo.attachedToDevice {
            deviceInfo.profileType = .ExtendedGamepad
            deviceInfo.supportsMotion = true
        }
        if VgcManager.appRole == .EnhancementBridge { deviceInfo.supportsMotion = true }
        
        // microGamepad is only supported when running on Apple TV, so we transform to
        // Gamepad when bridging it over to a Central on iOS or OSX
        if deviceInfo.profileType == .MicroGamepad { deviceInfo.profileType = .Gamepad }
        self.sendDeviceInfo(deviceInfo)
        
    }
    
    func mapElement(elementToBeMapped: Element, peripheral: Peripheral) {
        
        if let mappedElementIdentifier = Elements.customMappings.mappings[elementToBeMapped.identifier] {
            
            let mappedElement = VgcManager.elements.elementFromIdentifier(mappedElementIdentifier)
            mappedElement.mappingComplete = true
            print("   Mapping \(elementToBeMapped.name) to \(mappedElement.name)")
            mappedElement.value = elementToBeMapped.value
            self.sendElementState(mappedElement)
            
        }
    }

    
}

