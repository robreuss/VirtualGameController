//
//  ViewController.swift
//  Performance_Central
//
//  Created by Rob Reuss on 10/4/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import VirtualGameController

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)
       
    }

    @objc func controllerDidConnect(notification: NSNotification) {
        
        // If we're enhancing a hardware controller, we should display the Peripheral UI
        // instead of the debug view UI
        if VgcManager.appRole == .EnhancementBridge { return }
        
        guard let newController: VgcController = notification.object as? VgcController else {
            vgcLogDebug("[SAMPLE] Got nil controller in controllerDidConnect")
            return
        }
        
        newController.extendedGamepad?.rightTrigger.valueChangedHandler = { (thumbstick, value, bool) in
            
            let valueDouble = Double(value)
            print(valueDouble)
            print("HANDLER: RIght Trigger: \(valueDouble)" as Any)
            
            newController.elements.rightTrigger.value = valueDouble as AnyObject
            let rightTrigger = newController.elements.rightTrigger

            VgcController.sendElementStateToAllPeripherals(rightTrigger)
        }
        
        // Refresh on all motion changes
        newController.motion?.valueChangedHandler = { (input: VgcMotion) in
            
            print("Motion: \(Double(input.attitude.x))")
            newController.elements.motionAttitudeX.value = input.attitude.x as AnyObject
            //VgcController.sendElementStateToAllPeripherals(newController.elements.motionAttitudeX)
        }

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

