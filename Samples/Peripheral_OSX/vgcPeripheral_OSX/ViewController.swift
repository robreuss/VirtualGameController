//
//  ViewController.swift
//  vgcPeripheral_OSX
//
//  Created by Rob Reuss on 10/17/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Cocoa
import GameController
import VirtualGameController

let peripheral = VgcManager.peripheral
let elements = VgcManager.elements

class ViewController: NSViewController {
    
    @IBOutlet weak var playerIndexLabel: NSTextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // This is triggered by the developer on the Central side, by setting the playerIndex value on the controller, triggering a
        // system message being sent over the wire to this Peripheral, resulting in this notification.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "gotPlayerIndex:", name: VgcNewPlayerIndexNotification, object: nil)
        
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)

        // REQUIRED: Set device info
        peripheral.deviceInfo = DeviceInfo(deviceUID: NSUUID().UUIDString, vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: false)
        
        print(peripheral.deviceInfo)
        
        VgcManager.peripheral.browseForServices()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "foundService:", name: VgcPeripheralFoundService, object: nil)

    }
    
    @objc func foundService(notification: NSNotification) {
        if VgcManager.peripheral.haveConnectionToCentral == true { return }
        let service = notification.object as! VgcService
        vgcLogDebug("Automatically connecting to service \(service.fullName) because Central-selecting functionality is not implemented in this project")
        VgcManager.peripheral.connectToService(service)
    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        self.view.window?.title = VgcManager.appRole.description
        
    }
    
    
    func sendButtonPush(element: Element) {
        
        element.value = 1
        peripheral.sendElementState(element)
        let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.2 * Double(NSEC_PER_SEC)))
        dispatch_after(delayTime, dispatch_get_main_queue()) {
            element.value = 0
            peripheral.sendElementState(element)
        }
        
    }
        
    @objc func gotPlayerIndex(notification: NSNotification) {
        
        let playerIndex: Int = notification.object as! Int
        playerIndexLabel.stringValue = "Player: \(playerIndex + 1)"
        
    }
    
    @IBAction func rightShoulderPush(sender: NSButton) { sendButtonPush(elements.rightShoulder) }
    @IBAction func leftShoulderPush(sender: NSButton) { sendButtonPush(elements.leftShoulder) }
    @IBAction func rightTriggerPush(sender: NSButton) { sendButtonPush(elements.rightTrigger) }
    @IBAction func leftTriggerPush(sender: NSButton) { sendButtonPush(elements.leftTrigger) }

    @IBAction func yPush(sender: NSButton) { sendButtonPush(elements.buttonY) }
    @IBAction func xPush(sender: NSButton) { sendButtonPush(elements.buttonX) }
    @IBAction func aPush(sender: NSButton) { sendButtonPush(elements.buttonA) }
    @IBAction func bPush(sender: NSButton) { sendButtonPush(elements.buttonB) }
    
    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

