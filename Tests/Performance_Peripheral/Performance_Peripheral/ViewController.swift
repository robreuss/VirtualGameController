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

    let numberOfMessagesToSendEachTime = 3
    let frequencyOfMessageBursts: TimeInterval = 1/60
    let elapsedTimeForMeasurements = 10.0 // seconds
    var lastDisplayOfData = Date().timeIntervalSince1970
    var totalTransitTime: TimeInterval = 0
    var countOfMeasurements: Double = 0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        VgcManager.loggerUseNSLog = true
        
        // Network performance info
        VgcManager.performanceSamplingDisplayFrequency = 30.0
        
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: false)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(ViewController.peripheralDidConnect(_:)), name: NSNotification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)

        // Look for Centrals
        VgcManager.peripheral.browseForServices()
        
    }
    
    // Connect to Central
    @objc func foundService(_ notification: Notification) {
        let vgcService = notification.object as! VgcService
        vgcLogDebug("[TESTING] Found service: \(vgcService.name), connecting...")
        VgcManager.peripheral.connectToService(vgcService)
    }
    
    // Connected to Central
    @objc func peripheralDidConnect(_ notification: Notification) {
        
        vgcLogDebug("[TESTING] Peripheral didConnect")
        
        vgcLogDebug("[TESTING] Setting up handler for return data from Central")
        
        // Setup handler for return data from Central
        let motionX: Element = VgcManager.elements.motionAttitudeX
        motionX.valueChangedHandlerForPeripheral = { (motionAttitudeX: Element) in
            
            let adjustedUnixTime = (motionAttitudeX.value as! Double)
            
            // Record the elapsed time in milliseconds
            let elapsed = (Date().timeIntervalSince1970 - adjustedUnixTime) * 1000.0
            self.totalTransitTime += elapsed
            self.countOfMeasurements += 1
            if Date().timeIntervalSince1970 - self.lastDisplayOfData > self.elapsedTimeForMeasurements {
                
                //
                // Latency is measured by getting the average round trip time, dividing it by two (for a single trip), and rounding that to two digits
                //
                let latency = (((self.totalTransitTime / self.countOfMeasurements) / 2.0) * 100).rounded() / 100
                
                vgcLogDebug("[TESTING] Latency measured over \(self.elapsedTimeForMeasurements) seconds, \(self.countOfMeasurements) messages: \(latency) ms")
                self.lastDisplayOfData = Date().timeIntervalSince1970
                self.totalTransitTime = 0
                self.countOfMeasurements = 0
                
            }
        }
        
        VgcManager.peripheral.stopBrowsingForServices()
        
        vgcLogDebug("[TESTING] Seting timer for sending messages to Central")
        vgcLogDebug("[TESTING] Waiting for first set of data: \(self.elapsedTimeForMeasurements) seconds...")
        Timer.scheduledTimer(timeInterval: frequencyOfMessageBursts, target: self, selector: #selector(sendCurrentTimeAsMessageValues), userInfo: nil, repeats: true)
        
    }
    
    // Send message values to Central at intervals based on timer
    @objc func sendCurrentTimeAsMessageValues() {
        
        for _ in 1...numberOfMessagesToSendEachTime {

            VgcManager.elements.motionAttitudeX.value = Date().timeIntervalSince1970 as AnyObject
            VgcManager.peripheral.sendElementState(VgcManager.elements.motionAttitudeX)
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

