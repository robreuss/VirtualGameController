//
//  ViewController.swift
//  CentralVirtualGameControllerOSXSample
//
//  Created by Rob Reuss on 9/24/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Cocoa
import GameController
import AppKit
import VirtualGameController

class ViewController: NSViewController {

    @IBOutlet weak var statusLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        
        VgcManager.startAs(.Bridge, customElements: CustomElements(), customMappings: CustomMappings())
        
        VgcController.startWirelessControllerDiscoveryWithCompletionHandler { () -> Void in
            
            print("SAMPLE: Discovery completion handler executed")
            
        }
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidConnect:", name: "VgcControllerDidConnectNotification", object: nil)
        
        /*
        let scrollview = NSScrollView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.size.width, height: self.view.bounds.size.height))
        scrollview.autoresizingMask = [NSAutoresizingMaskOptions.ViewHeightSizable, NSAutoresizingMaskOptions.ViewWidthSizable]
        scrollview.backgroundColor = NSColor.darkGrayColor()
        self.view.addSubview(scrollview)
        */

    }
    
    override func viewDidAppear() {
        
        super.viewDidAppear()
        self.view.window?.title = "\(VgcManager.centralServiceName!) (\(VgcManager.appRole.description))"
        
    }
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
      

    }

    override var representedObject: AnyObject? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


