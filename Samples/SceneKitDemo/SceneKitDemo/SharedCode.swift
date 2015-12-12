//
//  SharedCode.swift
//  SceneKitDemo
//
//  Created by Rob Reuss on 12/8/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation
import SceneKit
import VirtualGameController

class SharedCode: NSObject {
    
    var ship: SCNNode!
    var lightNode: SCNNode!
    var cameraNode: SCNNode!
    
    func setup(ship: SCNNode, lightNode: SCNNode, cameraNode: SCNNode) {
        
        self.ship = ship
        self.lightNode = lightNode
        self.cameraNode = cameraNode
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidConnect:", name: VgcControllerDidConnectNotification, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "controllerDidDisconnect:", name: VgcControllerDidDisconnectNotification, object: nil)
        
        VgcManager.includesPeerToPeer = false
        
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
        
        if VgcController.controllers().count > 1 {
            controller.disconnect()
            return
        }
        
        if controller.deviceInfo.controllerType == .MFiHardware { return }
        
        VgcManager.peripheralSetup = VgcPeripheralSetup()
        
        // Turn on motion to demonstrate that
        VgcManager.peripheralSetup.motionActive = false
        VgcManager.peripheralSetup.enableMotionAttitude = true
        VgcManager.peripheralSetup.enableMotionGravity = false
        VgcManager.peripheralSetup.enableMotionUserAcceleration = false
        VgcManager.peripheralSetup.enableMotionRotationRate = false
        VgcManager.peripheralSetup.sendToController(controller)
        
        // Dpad adjusts lighting position
        
        #if os(iOS) || os(tvOS)
        controller.extendedGamepad?.dpad.valueChangedHandler = { (dpad, xValue, yValue) in
            
            self.lightNode.position = SCNVector3(x: Float(xValue * 10), y: Float(yValue * 20), z: Float(yValue * 30) + 10)
            
        }
        #endif
        
        #if os(OSX)
            controller.extendedGamepad?.dpad.valueChangedHandler = { (dpad, xValue, yValue) in
                
                self.lightNode.position = SCNVector3(x: CGFloat(xValue * 10), y: CGFloat(yValue * 20), z: CGFloat(yValue * 30) + 10)
                
            }
        #endif
        
        
        // Left thumbstick controls move the plane left/right and up/down
        controller.extendedGamepad?.leftThumbstick.valueChangedHandler = { (dpad, xValue, yValue) in
            
            self.ship.runAction(SCNAction.moveTo(SCNVector3.init(xValue * 5, yValue * 5, 0.0), duration: 0.3))
            
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
            
            self.ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 10.0), count: 1))
            
        }
        
        // Right trigger draws the plane toward the user
        controller.extendedGamepad?.rightTrigger.valueChangedHandler = { (input, value, pressed) in
            
            self.scaleShipByValue(-(CGFloat((controller.extendedGamepad?.rightTrigger.value)!)))
            
        }
        
        // Get an image and apply it to the ship (image is set to my dog Digit, you'll see the fur)
        controller.elements.custom[CustomElementType.SendImage.rawValue]!.valueChangedHandler = { (controller, element) in
            
            //print("Custom element handler fired for Send Image: \(element.value)")
            
            #if os(OSX)
                let image = NSImage(data: element.value as! NSData)
            #endif
            #if os(iOS) || os(tvOS)
                let image = UIImage(data: element.value as! NSData)
            #endif
            
            // get its material
            let material = self.ship.childNodeWithName("shipMesh", recursively: true)!.geometry?.firstMaterial!
            /*
            // highlight it
            SCNTransaction.begin()
            SCNTransaction.setAnimationDuration(0.5)
            
            // on completion - unhighlight
            SCNTransaction.setCompletionBlock {
                SCNTransaction.begin()
                SCNTransaction.setAnimationDuration(0.5)
                
                #if os(OSX)
                    material!.emission.contents = NSColor.blackColor()
                #endif
                #if os(iOS) || os(tvOS)
                    material!.emission.contents = UIColor.blackColor()
                #endif
                
                SCNTransaction.commit()
            }
            */
            material!.diffuse.contents = image
            
            //SCNTransaction.commit()
        }
        
        // Position ship at a solid origin
        ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 1.3), count: 1))
        
        // Refresh on all motion changes
        controller.motion?.valueChangedHandler = { (input: VgcMotion) in
            
            let amplify = 3.14158
            
            // Invert these because we want to be able to have the ship display in a way
            // that mirrors the position of the iOS device
            let x = -(input.attitude.x) * amplify
            let y = -(input.attitude.z) * amplify
            let z = -(input.attitude.y) * amplify
            
            self.ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(CGFloat(x), y: CGFloat(y), z: CGFloat(z), duration: 0.15), count: 1))
            
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
        /*
        // Refresh on all motion changes
        controller.motion?.valueChangedHandler = { (input: VgcMotion) in
        
        let amplify = 2.75
        
        // Invert these because we want to be able to have the ship display in a way
        // that mirrors the position of the iOS device
        let x = -(input.attitude.x) * amplify
        let y = -(input.attitude.z) * amplify
        let z = -(input.attitude.y) * amplify
        
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
        */
        
        
    }
    
    @objc func controllerDidDisconnect(notification: NSNotification) {
        
        //guard let controller: VgcController = notification.object as? VgcController else { return }
        
        ship.runAction(SCNAction.repeatAction(SCNAction.rotateToX(0, y: 0, z: 0, duration: 1.0), count: 1))
        
    }
    
    
}
