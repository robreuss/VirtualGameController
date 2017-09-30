//
//  ViewController.swift
//  ARKit_Ship_Demo
//
//  Created by Rob Reuss on 9/29/17.
//  Copyright © 2017 Rob Reuss. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import GameController
import VirtualGameController

class ViewController: UIViewController, ARSCNViewDelegate {
    
    var ship1: SCNNode!
    var ship2: SCNNode!
    var lightNode: SCNNode!
    var cameraNode: SCNNode!

    @IBOutlet var sceneView: ARSCNView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.controllerDidConnect(_:)), name: NSNotification.Name(rawValue: VgcControllerDidConnectNotification), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.foundService(_:)), name: NSNotification.Name(rawValue: VgcPeripheralFoundService), object: nil)
        
        VgcManager.useRandomServiceName = true
        // Publishes the CENTRAL service in case we want to operate as both
        // When running as both, central service must be started FIRST
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false)
        
        // Run as a PERIPHERAL
        VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: true)
        
        // Run in LOCAL mode so that the device also sends controller data to itself, so it is both running the game and forwarding control
        // activity to another device
        //VgcManager.startAs(.Peripheral, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings(), includesPeerToPeer: false, enableLocalController: true)
        
        // Set peripheral device info
        // Send an empty string for deviceUID and UID will be auto-generated and stored to user defaults
        //VgcManager.peripheral.deviceInfo = DeviceInfo(deviceUID: "", vendorName: "", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
        
        // Kick off the search for Centrals and Bridges that we can connect to.  When
        // services are found, the VgcPeripheralFoundService will fire.
        VgcManager.peripheral.browseForServices()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // retrieve the ship node
        ship1 = scene.rootNode.childNode(withName: "ship", recursively: true)!
        ship2 = ship1.clone()
        sceneView.scene.rootNode.addChildNode(ship2)
        
        let dpadSize = self.sceneView.bounds.size.height * 0.20
        let lightBlackColor = UIColor.init(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)
        
        let leftThumbstickPad = VgcStick(frame: CGRect(x: 0, y: self.sceneView.bounds.size.height - dpadSize, width: dpadSize, height: dpadSize), xElement: VgcManager.elements.leftThumbstickXAxis, yElement: VgcManager.elements.leftThumbstickYAxis)
        //let leftThumbstickPad = VgcStick(frame: CGRect(x: 0, y: self.sceneView.bounds.size.height - dpadSize, width: dpadSize, height: dpadsize))
        leftThumbstickPad.nameLabel.text = "dpad"
        leftThumbstickPad.nameLabel.textColor = UIColor.lightGray
        leftThumbstickPad.nameLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
        leftThumbstickPad.valueLabel.textColor = UIColor.lightGray
        leftThumbstickPad.valueLabel.font = UIFont(name: leftThumbstickPad.nameLabel.font.fontName, size: 15)
        leftThumbstickPad.backgroundColor = lightBlackColor
        leftThumbstickPad.controlView.backgroundColor = lightBlackColor
        sceneView.addSubview(leftThumbstickPad)
        

    }
    
    
    // Auto-connect to opposite device
    @objc func foundService(_ notification: Notification) {
        print("Received notification because found Central service")
        let vgcService = notification.object as! VgcService
        VgcManager.peripheral.connectToService(vgcService)
    }
    
    func scaleShipByValue( scale: CGFloat) {
        var scale = scale
        scale = scale * 20
        //if scale < 0.2 { scale = 0.2 }
        //if scale > -10 { scale = -10 }
        print("Current scale: \(scale)")
        ship1.runAction(SCNAction.scale(to: -scale, duration: 1.0))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)

    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
/*
    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
     
        return node
    }
*/
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func registerControllers(controller: VgcController) {
        
        var currentShip: SCNNode
        
        if controller.isLocalController {
            currentShip = ship1
        } else {
            currentShip = ship2
        }
        
        // Left thumbstick controls move the plane left/right and up/down
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            currentShip.runAction(SCNAction.move(to: SCNVector3.init(xValue * 2, yValue * 2, 0.0), duration: 0.3))
            
        }
        
        // Left thumbstick controls move the plane left/right and up/down
        controller.extendedGamepad?.rightThumbstick.valueChangedHandler = { (dpad, xValue, zValue) in
            
            currentShip.runAction(SCNAction.move(to: SCNVector3.init(self.ship1.position.x, self.ship1.position.y, zValue * 3), duration: 0.3))
            
        }
        
        
        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            //print("LOCAL HANDLER: Global handler fired, Left thumbstick value: \(gamepad.leftThumbstick.xAxis.value)")
            
        }
        
        // Refresh on all extended gamepad changes (Global handler)
        controller.extendedGamepad?.valueChangedHandler = { (gamepad: GCExtendedGamepad, element: GCControllerElement) in
            
            //print("LOCAL HANDLER: Profile level (Extended), Left thumbstick value: \(gamepad.leftThumbstick.xAxis.value)  ")
            
        }
        
     }
 
    @objc func controllerDidConnect(_ notification: Notification) {
        
        guard let controller: VgcController = notification.object as? VgcController else { return }
    
        registerControllers(controller: controller)
        
    }
    
    
    @objc func peripheralDidConnect(_ notification: Notification) {
        
        vgcLogDebug("Got VgcPeripheralDidConnectNotification notification")
        VgcManager.peripheral.stopBrowsingForServices()
        
    }
}
