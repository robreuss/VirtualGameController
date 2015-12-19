//
//  GameViewController.swift
//  SceneKitDemo
//
//  Created by Rob Reuss on 12/8/15.
//  Copyright (c) 2015 Rob Reuss. All rights reserved.
//

import QuartzCore
import SceneKit
import GameController
import VirtualGameController
#if os(iOS) || os(tvOS)
import UIKit
#endif

var ship: SCNNode!
var lightNode: SCNNode!
var cameraNode: SCNNode!
var sharedCode: SharedCode!

class GameViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: true)
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a camera to the scene
        cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // create and add a light to the scene
        lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = SCNLightTypeOmni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        lightNode.eulerAngles = SCNVector3Make(0.0, 3.1415/2.0, 0.0);
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        #if os(OSX)
            ambientLightNode.light!.color = NSColor.darkGrayColor()
        #endif
        #if os(iOS) || os(tvOS)
            ambientLightNode.light!.color = UIColor.darkGrayColor()
        #endif
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
        ship = scene.rootNode.childNodeWithName("ship", recursively: true)!
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        #if os(OSX)
            scnView.backgroundColor = NSColor.blackColor()
        #endif
        #if os(iOS) || os(tvOS)
            scnView.backgroundColor = UIColor.blackColor()
        #endif

        sharedCode = SharedCode()
        sharedCode.setup(ship, lightNode: lightNode, cameraNode: cameraNode)
 
        //scnView.delegate = sharedCode
    }
    
}
