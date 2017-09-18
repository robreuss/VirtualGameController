//
//  ViewController.swift
//  CentralVirtualGameControllerOSXSample
//
//  Created by Rob Reuss on 9/24/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Cocoa
import AppKit
import VirtualGameController

class ViewController: NSViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
        
        VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in
            
            vgcLogDebug("SAMPLE: Discovery completion handler executed")
            
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)

    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        self.view.window?.title = "\(VgcManager.centralServiceName!) (\(VgcManager.appRole.description))"
        
    }
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
      

    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


