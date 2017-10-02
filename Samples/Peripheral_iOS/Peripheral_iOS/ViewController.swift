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
import CoreMotion

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    var peripheralControlPadView: PeripheralControlPadView!
    var imagePicker: UIImagePickerController!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.watchDidConnect(_:)), name: NSNotification.Name(rawValue: VgcWatchDidConnectNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.watchDidDisconnect(_:)), name: NSNotification.Name(rawValue: VgcWatchDidDisconnectNotification), object: nil)
        
         // Use a compiler flag to control the logging level, dropping it to just errors if this
        // is a release build.
        #if Release
        VgcManager.loggerLogLevel = .Error // Minimal logging
        #else
        VgcManager.loggerLogLevel = .Debug // Robust logging
        #endif
        
        VgcManager.loggerUseNSLog = true
        
        // Must be turned ON on both ends (Peripheral and Central) because it effects the size of data headers
        VgcManager.netServiceLatencyLogging = false
        
        // Network performance info
        VgcManager.performanceSamplingDisplayFrequency = 10.0
 
        // Publishes the CENTRAL service in case we want to operate as both
        // When running as both, central service must be started FIRST
        //VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
        
        // Run as a PERIPHERAL
        //VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)
        
        // Run in LOCAL mode so that the device also sends controller data to itself, so it is both running the game and forwarding control
        // activity to another device
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: false)

        // Set peripheral device info
        // Send an empty string for deviceUID and UID will be auto-generated and stored to user defaults
        VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
        
        // This property needs to be set to a specific iCade controller to enable the functionality.  This
        // cannot be done by automatically discovering the identity of the controller; rather, it requires
        // presenting a list of controllers to the user and let them choose.
        VgcManager.iCadeControllerMode = .Disabled
        
        // Display our basic controller UI for debugging purposes
        peripheralControlPadView = PeripheralControlPadView(vc: self)

        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.peripheralDidDisconnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidDisconnectNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.peripheralDidConnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.peripheralConnectionFailed(_:)), name: NSNotification.Name(rawValue: VgcPeripheralConnectionFailedNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedSystemMessage(_:)), name: NSNotification.Name(rawValue: VgcSystemMessageNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.receivedPeripheralSetup(_:)), name: NSNotification.Name(rawValue: VgcPeripheralSetupNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.lostService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralLostService), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.serviceBrowserReset(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidResetBrowser), object: nil)
        
        // Kick off the search for Centrals and Bridges that we can connect to.  When
        // services are found, the VgcPeripheralFoundService will fire.
        VgcManager.peripheral.browseForServices()
        
        VgcManager.peripheral.motion.updateInterval = 1/60
        
        VgcManager.peripheral.motion.enableAttitude = true
        VgcManager.peripheral.motion.enableGravity = true
        VgcManager.peripheral.motion.enableRotationRate = true
        VgcManager.peripheral.motion.enableUserAcceleration = true
        
        VgcManager.peripheral.motion.enableAdaptiveFilter = true
        VgcManager.peripheral.motion.enableLowPassFilter = true

        
        // Skip sending float values if they are the same as the preceding value
        VgcManager.enableDupFiltering = false
        VgcManager.dupFilteringPrecision = 3
        
        if let element: Element = VgcManager.elements.elementFromIdentifier(CustomElementType.DebugViewTap.rawValue) {
       
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                vgcLogDebug("[SAMPLE] Custom element handler fired for \(element.name)")
                
                self.peripheralControlPadView.flashView.backgroundColor = UIColor.blue
                UIView.animate(withDuration: 0.05, delay: 0.0, options: .curveEaseIn, animations: {
                    self.peripheralControlPadView.flashView!.alpha = 1
                    }, completion: { finished in
                        self.peripheralControlPadView.flashView!.alpha = 0
                })
                
            }
        }
        
        let element: Element = VgcManager.elements.image
            
        element.valueChangedHandlerForPeripheral = { (element: Element) in
            
            vgcLogDebug("[SAMPLE] Custom element handler fired for Send Image")
            self.peripheralControlPadView.flashView.image = nil
            self.peripheralControlPadView.flashView.image = UIImage(data: (element.value as! NSData) as Data)
            self.peripheralControlPadView.flashView.contentMode = UIViewContentMode.bottom
            self.peripheralControlPadView.flashView.alpha = 1.0
            self.peripheralControlPadView.flashView.backgroundColor = UIColor.clear
        }
        
        if let element: Element = VgcManager.elements.elementFromIdentifier(CustomElementType.Keyboard.rawValue) {
            
            element.valueChangedHandlerForPeripheral = { (element: Element) in
                
                vgcLogDebug("[SAMPLE] Custom element handler fired for \(element.name) with value \(element.value)")
                
                self.peripheralControlPadView.flashView.backgroundColor = UIColor.brown
                UIView.animate(withDuration: 0.05, delay: 0.0, options: .curveEaseIn, animations: {
                    self.peripheralControlPadView.flashView!.alpha = 1
                    }, completion: { finished in
                        self.peripheralControlPadView.flashView!.alpha = 0
                })
            }
        }
        
        let rightShoulderElement: Element = VgcManager.elements.rightShoulder
            
        rightShoulderElement.valueChangedHandlerForPeripheral = { (rightShoulderElement: Element) in
            
            vgcLogDebug("[SAMPLE] Custom element handler fired for \(rightShoulderElement.name) with value \(rightShoulderElement.value)")
            
            self.peripheralControlPadView.flashView.backgroundColor = UIColor.green
            UIView.animate(withDuration: 0.05, delay: 0.0, options: .curveEaseIn, animations: {
                self.peripheralControlPadView.flashView!.alpha = 1
                }, completion: { finished in
                    self.peripheralControlPadView.flashView!.alpha = 0
            })
        }
        
        // Handle element messages from watch.  No need to forward to Central, which is handled
        // automatically - only here for other processing.
        VgcManager.peripheral.watch.valueChangedHandler = { (element: Element) in
            
            vgcLogDebug("[SAMPLE] Value changed handler received element state from watch: \(element.name) with value \(element.value)")
            
        }

        
    }
    
    @objc func displayPhotoPicker(_ sender: AnyObject) {

        imagePicker =  UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = .camera
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        
        imagePicker.dismiss(animated: true) { () -> Void in
            
            let imageElement = VgcManager.elements.elementFromIdentifier(ElementType.image.rawValue)
            let imageData = UIImageJPEGRepresentation(image, 1.0)
            imageElement?.value = imageData! as AnyObject
            imageElement?.clearValueAfterTransfer = true
            VgcManager.peripheral.sendElementState(imageElement!)
            
        }

    }

    // Add new service to our list of available services.  I'm not using here, but the
    // newly found VgcService object is included with the notification.
    @objc func foundService(_ notification: Notification) {
        let vgcService = notification.object as! VgcService
        vgcLogDebug("[SAMPLE] Found service: \(vgcService.fullName) isMainThread: \(Thread.isMainThread)")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
 
    // Refresh list of available services because one went offline. 
    // I'm not using here, but the lost VgcService object is included with the notification.
    @objc func lostService(_ notification: Notification) {
        let vgcService = notification.object as? VgcService
        vgcLogDebug("[SAMPLE] Lost service: \(vgcService!.fullName) isMainThread: \(Thread.isMainThread)")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
    
    // Watch reachability changed
    @objc func watchDidConnect(_ notification: Notification) {
        vgcLogDebug("[SAMPLE] Got watch did connect notification \(VgcManager.peripheral)")
    }
    
    // Watch reachability changed
    @objc func watchDidDisconnect(_ notification: Notification) {
        vgcLogDebug("[SAMPLE] Got watch did disconnect notification")
    }
    
    // Notification indicates we should refresh the view
    @objc func serviceBrowserReset(_ notification: Notification) {
        vgcLogDebug("[SAMPLE] Service browser reset, isMainThread: \(Thread.isMainThread)")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
    
    // Notification indicates connection failed
    @objc func peripheralConnectionFailed(_ notification: Notification) {
        vgcLogDebug("[SAMPLE] Peripheral connect failed, isMainThread: \(Thread.isMainThread)")
        peripheralControlPadView.serviceSelectorView.refresh()
    }
    
    // The Central has sent PeripheralSetup information
    @objc func receivedPeripheralSetup(_ notification: Notification) {
      
        if VgcManager.peripheralSetup.motionActive {
            VgcManager.peripheral.motion.start()
        } else {
            VgcManager.peripheral.motion.stop()
        }
        
        VgcManager.peripheral.motion.enableUserAcceleration = VgcManager.peripheralSetup.enableMotionUserAcceleration
        VgcManager.peripheral.motion.enableGravity = VgcManager.peripheralSetup.enableMotionGravity
        VgcManager.peripheral.motion.enableRotationRate = VgcManager.peripheralSetup.enableMotionRotationRate
        VgcManager.peripheral.motion.enableAttitude = VgcManager.peripheralSetup.enableMotionAttitude
        
        VgcManager.peripheral.deviceInfo.profileType = VgcManager.peripheralSetup.profileType
        print(VgcManager.peripheralSetup)
        for view in peripheralControlPadView.parentView.subviews {
            view.removeFromSuperview()
        }
        peripheralControlPadView = PeripheralControlPadView(vc: self)
        peripheralControlPadView.controlOverlay.frame = CGRect(x: 0, y: -peripheralControlPadView.parentView.bounds.size.height, width: peripheralControlPadView.parentView.bounds.size.width, height: peripheralControlPadView.parentView.bounds.size.height)

        peripheralControlPadView.parentView.backgroundColor = VgcManager.peripheralSetup.backgroundColor
    }
    

    @objc func receivedSystemMessage(_ notification: Notification) {
        
        let systemMessageTypeRaw = notification.object as! Int
        let systemMessageType = SystemMessages(rawValue: systemMessageTypeRaw)
        if systemMessageType == SystemMessages.receivedInvalidMessage {
            
            if VgcManager.peripheral.motion.active == true {
                
                // Decrease motion update interval to prevent invalid messages
                //VgcManager.peripheral.motion.updateInterval = VgcManager.peripheral.motion.updateInterval + (VgcManager.peripheral.motion.updateInterval * 0.05)
                //vgcLogDebug("Modifying motion update interval to \(VgcManager.peripheral.motion.updateInterval)")
                
            }
            
            // Flash the UI red to indicate bad messages being sent
            self.peripheralControlPadView.flashView.backgroundColor = UIColor.red
            UIView.animate(withDuration: 0.1, delay: 0.0, options: .curveEaseIn, animations: {
                self.peripheralControlPadView.flashView!.alpha = 1
                }, completion: { finished in
                self.peripheralControlPadView.flashView!.alpha = 0
            })

        }
    }
    
    
    @objc func localControllerDidConnect(_ notification: Notification) {
        
        guard let controller: VgcController = notification.object as? VgcController else { return }

        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            print("[SAMPLE] LOCAL HANDLER: Global handler fired, Left thumbstick value: \(gamepad.leftThumbstick.xAxis.value)")
            
        }
        
        // Refresh on all extended gamepad changes (Global handler)
        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            print("[SAMPLE] LOCAL HANDLER: Profile level (Extended), Left thumbstick value: \(gamepad.leftThumbstick.xAxis.value)  ")
            
        }
        
        controller.extendedGamepad?.leftThumbstick.xAxis.valueChangedHandler = { (thumbstick, value) in
            
            
            print("[SAMPLE] LOCAL HANDLER: Left thumbstick xAxis: \(value)  \(thumbstick.value)")
            
        }
        
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            print("[SAMPLE] LOCAL HANDLER: Left Thumbstick: \(xValue), \(yValue)")
            
        }


        
    }
    
    
    @objc func peripheralDidConnect(_ notification: Notification) {
        
        vgcLogDebug("[SAMPLE] Got VgcPeripheralDidConnectNotification notification")
        VgcManager.peripheral.stopBrowsingForServices()
        

        #if !os(tvOS)
            if VgcManager.peripheral.deviceInfo.profileType == .MicroGamepad {
                
                // We're mimicing the Apple TV remote here, which starts with motion turned on
                VgcManager.peripheral.motion.enableAttitude = false
                VgcManager.peripheral.motion.enableUserAcceleration = true
                VgcManager.peripheral.motion.enableGravity = true
                VgcManager.peripheral.motion.enableRotationRate = false
                VgcManager.peripheral.motion.start()
            }
        #endif
        
            // Data load testing
        
        //var motionPollingTimer = Timer.scheduledTimer(timeInterval: 0.004, target: self, selector: #selector(sendRandomData), userInfo: nil, repeats: true)
    }
    /*
    @objc func sendRandomData() {
        VgcManager.elements.rightTrigger.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.rightTrigger)
        
        VgcManager.elements.leftTrigger.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.leftTrigger)
        
        VgcManager.elements.rightShoulder.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.rightShoulder)
        
        VgcManager.elements.leftShoulder.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.leftShoulder)
        
        
        VgcManager.elements.dpadXAxis.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.dpadXAxis)
        
        VgcManager.elements.dpadYAxis.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.dpadYAxis)
        
        VgcManager.elements.leftThumbstickXAxis.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.leftThumbstickXAxis)
        
        VgcManager.elements.leftThumbstickYAxis.value = CGFloat(Float(arc4random()) / Float(UINT32_MAX)) as AnyObject
        VgcManager.peripheral.sendElementState(VgcManager.elements.leftThumbstickYAxis)

    }
*/
    
    @objc func peripheralDidDisconnect(_ notification: Notification) {
        
        vgcLogDebug("[SAMPLE] Got VgcPeripheralDidDisconnectNotification notification")
        VgcManager.peripheral.browseForServices()
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

