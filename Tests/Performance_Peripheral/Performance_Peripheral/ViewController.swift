//
//  ViewController.swift
//  Performance_Peripheral
//
//  Created by Rob Reuss on 10/4/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import VirtualGameController

class ViewController: UIViewController {

    var numberOfMessages = 5
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: false)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.peripheralDidConnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)
        
        let motionAttitudeXELement: Element = VgcManager.elements.motionAttitudeX
        motionAttitudeXELement.valueChangedHandlerForPeripheral = { (motion: Element) in
 
            let adjustedUnixTime = (motion.value as! Double)
            let date = NSDate(timeIntervalSince1970: adjustedUnixTime)
            print("Received: \(date.timeIntervalSince1970)")
            
        }
        
        let rightTriggerElement: Element = VgcManager.elements.rightTrigger
        
        rightTriggerElement.valueChangedHandlerForPeripheral = { (rightTriggerElement: Element) in
            
            //vgcLogDebug("[SAMPLE] Custom element handler fired for \(rightTriggerElement.name) with value \(rightTriggerElement.value)")
            
            let adjustedUnixTime = (rightTriggerElement.value as! Double)
            let date = NSDate(timeIntervalSince1970: adjustedUnixTime)
            
            print("Received: \(date.timeIntervalSince1970)")
            
            let formatter = DateFormatter()
            // initially set the format based on your datepicker date
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let myString = formatter.string(from: Date())
            // convert your string to date
            let yourDate = formatter.date(from: myString)
            //then again set the date format whhich type of output you need
            formatter.dateFormat = "dd-MMM-yyyy"
            // again convert your date to string
            let myStringafd = formatter.string(from: date as Date)
            
            //print(myStringafd)
            
        }
        
        // Look for Centrals.  Note, system is automatically setup to use UID-based device names so that a
        // Peripheral device does not try to connect to it's own Central service.
        VgcManager.peripheral.browseForServices()
    }
    
    @objc func sendTimeAsMessageValues() {
        
        for var messageNumber in 1...numberOfMessages {

            let currentTimeString = Double(Date().timeIntervalSince1970)
            print("Sent:     \(Date().timeIntervalSince1970)")
            VgcManager.elements.rightTrigger.value = currentTimeString as AnyObject
            
            let myFloat: Double = 1507143232.64618
            let myFloatAny = myFloat as AnyObject
            let myNewFloat = myFloatAny as! Double
            print("My float: \(myFloat), \(myFloatAny),  \(myNewFloat)")
            
            //let data = VgcManager.elements.rightTrigger.valueAsNSData
            VgcManager.elements.rightTrigger.value = currentTimeString as AnyObject
            print("Sending value: \(VgcManager.elements.rightTrigger.value)")
            
            VgcManager.peripheral.sendElementState(VgcManager.elements.rightTrigger)
            
            //VgcManager.elements.motionAttitudeX.value = currentTimeString as AnyObject
            //VgcManager.peripheral.sendElementState(VgcManager.elements.motionAttitudeX)
            
        }
        
    }
    
    // Auto-connect to opposite device
    @objc func foundService(_ notification: Notification) {
        let vgcService = notification.object as! VgcService
        VgcManager.peripheral.connectToService(vgcService)
    }
    
    @objc func peripheralDidConnect(_ notification: Notification) {
        
        vgcLogDebug("[SAMPLE] Got VgcPeripheralDidConnectNotification notification")
        VgcManager.peripheral.stopBrowsingForServices()
        let messagesPerSecond: Double = 1/60
        let sendMessagesTimer = Timer.scheduledTimer(timeInterval: messagesPerSecond, target: self, selector: #selector(sendTimeAsMessageValues), userInfo: nil, repeats: true)

        
        // Data load testing
        
        //var motionPollingTimer = Timer.scheduledTimer(timeInterval: 0.004, target: self, selector: #selector(sendRandomData), userInfo: nil, repeats: true)
    }
    

    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

