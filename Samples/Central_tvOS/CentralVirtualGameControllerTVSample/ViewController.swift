//
//  ViewController.swift
//  CentralVirtualGameControllerTVSample
//
//  Created by Rob Reuss on 9/13/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import VirtualGameController

class ViewController: VgcCentralViewController {
    
    override func viewDidLoad() {
        
        // Publishes the central service
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings())

        super.viewDidLoad()
        
    }

}


