//  ViewController.swift
//  PeripheralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import UIKit
import GameController
import VirtualGameController

class ViewController: UIViewController {

    var peripheralControlPadView: PeripheralControlPadView!
  
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Initialize Peripheral
        VgcManager.startAs(.Peripheral, customElements: nil, customMappings: nil)

        // Set peripheral device info
        // Send an empty string for deviceUID and UID will be auto-generated and stored to user defaults
        VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
        
        // This property needs to be set to a specific iCade controller to enable the functionality.  This
        // cannot be done by automatically discovering the identity of the controller; rather, it requires
        // presenting a list of controllers to the user and let them choose.
        VgcManager.iCadeControllerMode = .Disabled
        
        // Display our basic controller UI for debugging purposes
        self.peripheralControlPadView = PeripheralControlPadView(aParentView: self.view)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidDisconnect:", name: VgcPeripheralDidDisconnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "peripheralDidConnect:", name: VgcPeripheralDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receivedSystemMessage:", name: VgcSystemMessageNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "lostService:", name: VgcPeripheralLostService, object: nil)
        
        // Kick off the search for Centrals and Bridges that we can connect to.  When
        // services are found, the VgcPeripheralFoundService will fire.
        VgcManager.peripheral.browseForServices()
        
    }

    // Add new service to our list of available services.  I'm not using here, but the
    // newly found VgcService object is included with the notification.
    @objc func foundService(notification: NSNotification) {
        let vgcService = notification.object as! VgcService
        print("Found service: \(vgcService.fullName)")
        self.peripheralControlPadView.serviceSelectorView.refresh()
    }
 
    // Refresh list of available services because one went offline. 
    // I'm not using here, but the lost VgcService object is included with the notification.
    @objc func lostService(notification: NSNotification) {
        let vgcService = notification.object as! VgcService
        print("Lost service: \(vgcService.fullName)")
        self.peripheralControlPadView.serviceSelectorView.refresh()
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
            UIView.animateWithDuration(0.1, delay: 0.0, options: .CurveEaseIn, animations: {
                self.peripheralControlPadView.flashView!.alpha = 1
                }, completion: { finished in
                self.peripheralControlPadView.flashView!.alpha = 0
            })

        }
    }

    @objc func peripheralDidConnect(notification: NSNotification) {
        
        print("Got VgcPeripheralDidConnectNotification notification")
        
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

