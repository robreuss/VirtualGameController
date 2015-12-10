//
//  GameViewController.swift
//  SceneKitDemo_iOS
//
//  Created by Rob Reuss on 11/25/15.
//  Copyright (c) 2015 Rob Reuss. All rights reserved.
//

import UIKit
import QuartzCore
import SceneKit
import GameController
import VirtualGameController

var ship: SCNNode!
var lightNode: SCNNode!
var cameraNode: SCNNode!
var scene: SCNScene!

class GameViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        VgcManager.startAs(.Central, appIdentifier: "vgc", customElements: CustomElements(), customMappings: CustomMappings())
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidConnect:", name: VgcControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidDisconnect:", name: VgcControllerDidDisconnectNotification, object: nil)
        
        // create a new scene
        scene = SCNScene(named: "art.scnassets/ship.scn")!
        
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
        lightNode.eulerAngles = SCNVector3Make(0.0, Float(M_PI)/2.0, 0.0);
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = SCNLightTypeAmbient
        ambientLightNode.light!.color = UIColor.darkGrayColor()
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
        scnView.backgroundColor = UIColor.blackColor()
        
    }
    
    func scaleShipByValue(var scaleValue: CGFloat) {
        scaleValue = scaleValue + 1
        if scaleValue < 0.10 { scaleValue = 0.10 }
        ship.runAction(SCNAction.scaleTo(scaleValue, duration: 1.0))
    }
    
    @objc func controllerDidConnect(notification: NSNotification) {
        
        // If we're enhancing a hardware controller, we should display the Peripheral UI
        // instead of the debug view UI
        if VgcManager.appRole == .EnhancementBridge { return }
      
        guard let controller: VgcController = notification.object as? VgcController else {
            print("Got nil controller in controllerDidConnect")
            return
        }
        
        if controller.deviceInfo.controllerType == .MFiHardware { return }
        
        // We only need attitude motion data
        VgcManager.peripheralSetup = VgcPeripheralSetup()
        VgcManager.peripheralSetup.motionActive = false // Let the user turn this on so they can orient the device, pointing it at the screen
        VgcManager.peripheralSetup.enableMotionAttitude = true
        VgcManager.peripheralSetup.enableMotionGravity = true
        VgcManager.peripheralSetup.enableMotionRotationRate = true
        VgcManager.peripheralSetup.enableMotionUserAcceleration = true
        VgcManager.peripheralSetup.sendToController(controller)
        
        
        // Dpad adjusts lighting position
        controller.extendedGamepad?.dpad.valueChangedHandler = { (dpad, xValue, yValue) in
            
            
            lightNode.position = SCNVector3(x: xValue * 10, y: yValue * 20, z: (yValue * 30) + 10)
            
        }
        
        // Left thumbstick controls move the plane left/right and up/down
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            ship.runAction(SCNAction.moveTo(SCNVector3.init(xValue * 5, yValue * 5, 0.0), duration: 0.3))
            
        }
        
        // Right thumbstick Y axis controls plane scale
        controller.extendedGamepad?.rightThumbstick.yAxis.valueChangedHandler = { (input, value) in
            
            self.scaleShipByValue(CGFloat((controller.extendedGamepad?.rightThumbstick.yAxis.value)!))
            
        }
        
        // Right Shoulder pushes the ship away from the user
        controller.extendedGamepad?.rightShoulder.valueChangedHandler = { (input, value, pressed) in
            
            self.scaleShipByValue(CGFloat((controller.extendedGamepad?.rightShoulder.value)!))
            
        }
        
        // Left Shoulder resets the reference frame
        controller.extendedGamepad?.leftShoulder.valueChangedHandler = { (input, value, pressed) in
            
            ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 10.0), count: 1))
            
        }
        
        // Right trigger draws the plane toward the user
        controller.extendedGamepad?.rightTrigger.valueChangedHandler = { (input, value, pressed) in
            
            self.scaleShipByValue(-(CGFloat((controller.extendedGamepad?.rightTrigger.value)!)))
            
        }
        
        // Right trigger draws the plane toward the user
        controller.extendedGamepad?.rightTrigger.valueChangedHandler = { (input, value, pressed) in
            
            self.scaleShipByValue(-(CGFloat((controller.extendedGamepad?.rightTrigger.value)!)))
            
        }
        
        // Get an image and apply it to the ship (image is set to my dog Digit, you'll see the fur)
        controller.elements.custom[CustomElementType.SendImage.rawValue]!.valueChangedHandler = { (controller, element) in
            
            //print("Custom element handler fired for Send Image: \(element.value)")
            
            let image = UIImage(data: element.value as! NSData)
            
            // get its material
            let material = ship.childNodeWithName("shipMesh", recursively: true)!.geometry?.firstMaterial!
            
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.setAnimationDuration(0.5)
            
            // on completion - unhighlight
            SCNTransaction.setCompletionBlock {
                SCNTransaction.begin()
                SCNTransaction.setAnimationDuration(0.5)
                
                material!.emission.contents = UIColor.blackColor()
                
                SCNTransaction.commit()
            }
            
            material!.diffuse.contents = image
            
            SCNTransaction.commit()
        }
        
        // Position ship at a solid origin
        ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 1.3), count: 1))
        
        // Refresh on all motion changes
        controller.motion?.valueChangedHandler = { (input: VgcMotion) in
            
            let amplify = 2.75
            
            // Invert these because we want to be able to have the ship display in a way
            // that mirrors the position of the iOS device
            let x = -(input.attitude.x) * amplify
            let y = -(input.attitude.z) * amplify
            let z = -(input.attitude.y) * amplify
            
            // Increase the duration value if you want to smooth out the motion of the ship,
            // so that hand shake is not reflected
            ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(CGFloat(x), y: CGFloat(y), z: CGFloat(z), duration: 0.15), count: 1))
            
            //ship.runAction(SCNAction.moveTo(SCNVector3.init(CGFloat(x) * 4.0, CGFloat(y) * 4.0, CGFloat(z) * 4.0), duration: 0.3))
            // The following will give the ship a bit of "float" that relates to the up/down motion of the iOS device.
            
            // Disable the following if you want to focus on using the on-screen device input controls instead of motion input.
            // If this section is not disabled, and you use the onscreen input controls, the two will "fight" over control
            // and create hurky jerky motion.
            
            /*
            var xValue = CGFloat(input.gravity.x)
            var yValue = CGFloat(input.userAcceleration.y)
            
            xValue = xValue + (xValue * 3.0)
            yValue = yValue - (yValue * 20.0)
            
            ship.runAction(SCNAction.moveTo(SCNVector3.init(xValue, yValue, CGFloat( ship.position.z)), duration: 1.6))
            */
        }
        
        
        
    }
    
    @objc func controllerDidDisconnect(notification: NSNotification) {
        
        //guard let controller: VgcController = notification.object as? VgcController else { return }
        
        ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 1.0), count: 1))
        
    }
    
    #if !(os(tvOS))
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        if UIDevice.currentDevice().userInterfaceIdiom == .Phone {
            return .AllButUpsideDown
        } else {
            return .All
        }
    }
    #endif
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
    
}
