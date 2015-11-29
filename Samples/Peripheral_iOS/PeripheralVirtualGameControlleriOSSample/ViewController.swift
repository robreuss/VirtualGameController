//  ViewController.swift
//  PeripheralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import UIKit
import GameController
import VirtualGameController
//import <AudioToolbox/AudioServices.h>
import AudioToolbox

class ViewController: UIViewController {

    var peripheralControlPadView: PeripheralControlPadView!
  
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Initialize Peripheral
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings())

        // Set peripheral device info
        // Send an empty string for deviceUID and UID will be auto-generated and stored to user defaults
        VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
        
        // This property needs to be set to a specific iCade controller to enable the functionality.  This
        // cannot be done by automatically discovering the identity of the controller; rather, it requires
        // presenting a list of controllers to the user and let them choose.
        VgcManager.iCadeControllerMode = .Disabled
        
        // Display our basic controller UI for debugging purposes
        peripheralControlPadView = PeripheralControlPadView(aParentView: self.view)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidDisconnect:", name: VgcPeripheralDidDisconnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidConnect:", name: VgcPeripheralDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedSystemMessage:", name: VgcSystemMessageNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedPeripheralSetup:", name: VgcPeripheralSetupNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "lostService:", name: VgcPeripheralLostService, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "serviceBrowserReset:", name: VgcPeripheralDidResetBrowser, object: nil)
        
        // Kick off the search for Centrals and Bridges that we can connect to.  When
        // services are found, the VgcPeripheralFoundService will fire.
        VgcManager.peripheral.browseForServices()
        
        VgcManager.includesPeerToPeer = false
        
        VgcManager.peripheral.motion.updateInterval = 1/30
        
        VgcManager.peripheral.motion.enableAttitude = true
        VgcManager.peripheral.motion.enableGravity = false
        VgcManager.peripheral.motion.enableRotationRate = false
        VgcManager.peripheral.motion.enableUserAcceleration = true
        
        VgcManager.peripheral.motion.enableAdaptiveFilter = true
        VgcManager.peripheral.motion.enableLowPassFilter = true
        
        if let element: Element = VgcManager.elements.elementFromIdentifier(CustomElementType.DebugViewTap.rawValue) {
       
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                print("Custom element handler fired for \(element.name)")
                
                self.peripheralControlPadView.flashView.backgroundColor = UIColor.blueColor()
                UIView.animateWithDuration(0.05, delay: 0.0, options: .CurveEaseIn, animations: {
                    self.peripheralControlPadView.flashView!.alpha = 1
                    }, completion: { finished in
                        self.peripheralControlPadView.flashView!.alpha = 0
                })
                
            }
        }
        
        if let element: Element = VgcManager.elements.elementFromIdentifier(CustomElementType.Keyboard.rawValue) {
            
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                print("Custom element handler fired for \(element.name) with value \(element.value)")
                
                self.peripheralControlPadView.flashView.backgroundColor = UIColor.brownColor()
                UIView.animateWithDuration(0.05, delay: 0.0, options: .CurveEaseIn, animations: {
                    self.peripheralControlPadView.flashView!.alpha = 1
                    }, completion: { finished in
                        self.peripheralControlPadView.flashView!.alpha = 0
                })
                
            }
        }
        
        if let element: Element = VgcManager.elements.rightShoulder {
            
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                print("Custom element handler fired for \(element.name) with value \(element.value)")
                
                self.peripheralControlPadView.flashView.backgroundColor = UIColor.greenColor()
                UIView.animateWithDuration(0.05, delay: 0.0, options: .CurveEaseIn, animations: {
                    self.peripheralControlPadView.flashView!.alpha = 1
                    }, completion: { finished in
                        self.peripheralControlPadView.flashView!.alpha = 0
                })
                
            }
        }
        
        if let element: Element = VgcManager.elements.elementFromIdentifier(CustomElementType.VibrateDevice.rawValue) {
            
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                print("Custom element handler fired for \(element.name) with value \(element.value)")
                
                AudioServicesPlayAlertSound(UInt32(kSystemSoundID_Vibrate))
                
            }
        }

        
    }

    // Add new service to our list of available services.  I'm not using here, but the
    // newly found VgcService object is included with the notification.
    @objc func foundService(notification: NSNotification) {
        let vgcService = notification.object as! VgcService
        print("Found service: \(vgcService.fullName) isMainThread: \(NSThread.isMainThread())")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
 
    // Refresh list of available services because one went offline. 
    // I'm not using here, but the lost VgcService object is included with the notification.
    @objc func lostService(notification: NSNotification) {
        let vgcService = notification.object as? VgcService
        print("Lost service: \(vgcService!.fullName) isMainThread: \(NSThread.isMainThread())")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
    
    // Notification indicates we should refresh the view
    @objc func serviceBrowserReset(notification: NSNotification) {
        print("Service browser reset, isMainThread: \(NSThread.isMainThread())")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
    
    // Notification indicates we should refresh the view
    @objc func receivedPeripheralSetup(notification: NSNotification) {
        peripheralControlPadView.parentView.backgroundColor = VgcManager.peripheralSetup.backgroundColor
        print(VgcManager.peripheralSetup)
    }
    
    // There is only one system message, currently, that is relevant to Peripherals,
    // .ReceivedInvalidMessage, which comes from the Central when the Central receives a
    // malformed element value message.  This is only known to happen when attempting to
    // send too much motion data on a slower device like the iPhone 4s.  I'm using the 
    // message in this case to throttle back the amount of motion data being sent from
    // the device.
    @objc func receivedSystemMessage(notification: NSNotification) {
        
        let systemMessageTypeRaw = notification.object as! Int
        let systemMessageType = SystemMessages(rawValue: systemMessageTypeRaw)
        if systemMessageType == SystemMessages.ReceivedInvalidMessage {
            
            if VgcManager.peripheral.motion.active == true {
                
                // Decrease motion update interval to prevent invalid messages
                VgcManager.peripheral.motion.updateInterval = VgcManager.peripheral.motion.updateInterval + (VgcManager.peripheral.motion.updateInterval * 0.05)
                print("Modifying motion update interval to \(VgcManager.peripheral.motion.updateInterval)")
                
            }
            
            // Flash the UI red to indicate bad messages being sent
            self.peripheralControlPadView.flashView.backgroundColor = UIColor.redColor()
            UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseIn, animations: {
                self.peripheralControlPadView.flashView!.alpha = 1
                }, completion: { finished in
                self.peripheralControlPadView.flashView!.alpha = 0
            })

        }
    }

    @objc func peripheralDidConnect(notification: NSNotification) {
        
        print("Got VgcPeripheralDidConnectNotification notification")
        VgcManager.peripheral.stopBrowsingForServices()
        
    }
    
    @objc func peripheralDidDisconnect(notification: NSNotification) {
        
        print("Got VgcPeripheralDidDisconnectNotification notification")
        VgcManager.peripheral.browseForServices()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

