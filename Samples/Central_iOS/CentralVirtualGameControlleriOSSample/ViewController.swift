//
//  ViewController.swift
//  CentralVirtualGameControlleriOSSample
//
//  Created by Rob Reuss on 9/14/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import VirtualGameController


// Note that sample apps for both Bridge and Central descend from a common
// ancestor class that contains much of the functionality.
class ViewController: VgcCentralViewController {
    
    
    override func viewDidLoad() {
        
         // Publishes the central service
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
        super.viewDidLoad()
        
    }


}
