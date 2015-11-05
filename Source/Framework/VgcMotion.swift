//
//  VgcMotionManager.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//


import Foundation
#if !(os(tvOS)) && !(os(OSX))
import CoreMotion

public class VgcMotionManager: NSObject {

    #if os(iOS)
    private let elements = VgcManager.peripheral.elements
    #endif
    
    #if os(watchOS)
    public var watchConnectivity: VgcWatchConnectivity!
    private var elements: Elements!
    #endif
    
    public var deviceSupportsMotion: Bool!
    
    public let manager = CMMotionManager()
    
    public var active: Bool = false
    
    ///
    /// System can handle 60 updates/sec but only if a subset of motion factors are enabled,
    /// not all four.  If all four inputs are needed, update frequency should be reduced.
    ///
    public var updateInterval = 1.0 / 60 {
        didSet {
            manager.deviceMotionUpdateInterval = updateInterval
        }
    }
                
    public override init() {

        #if os(watchOS)
        elements = watchConnectivity.elements
        #endif
        
        super.init()
        
    }
    
    public func start() {
 
        #if os(iOS) || os(watchOS)
            
            print("Attempting to start motion detection")
            
            #if os(iOS)
                if (VgcManager.peripheral.haveConnectionToCentral == false && VgcManager.appRole != .EnhancementBridge) || (VgcManager.appRole == .EnhancementBridge && VgcController.enhancedController.peripheral.haveConnectionToCentral == false) {
                    print("Not starting motion because no connection")
                    return
                }
            #endif
            
            // No need to start if already active
            if manager.deviceMotionActive {
                print("Not starting motion because already active")
                return
            }
            
            print("Device supports: \(self.deviceSupportsMotion), motion available: \(self.manager.deviceMotionAvailable), accelerometer available: \(self.manager.accelerometerAvailable)")
            
            if self.deviceSupportsMotion == true {
                
                active = true
                
                // iOS supports device motion, but the watch only supports direct accelerometer data
                if self.manager.deviceMotionAvailable {
                    
                    print("Starting device motion updating")
                    manager.deviceMotionUpdateInterval = NSTimeInterval(self.updateInterval)
                    manager.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (deviceMotionData, error) -> Void in
                        
                        //print("Device Motion: \(deviceMotionData!)")
                        
                        self.elements.motionAttitudeY.value = Float((deviceMotionData?.attitude.quaternion.y)!)
                        self.elements.motionAttitudeX.value = Float((deviceMotionData?.attitude.quaternion.x)!)
                        self.elements.motionAttitudeZ.value = Float((deviceMotionData?.attitude.quaternion.z)!)
                        self.elements.motionAttitudeW.value = Float((deviceMotionData?.attitude.quaternion.w)!)
                        
                        // Send data on the custom accelerometer channels
                        if VgcManager.enableMotionAttitude {
                            self.sendElementState(self.elements.motionAttitudeY)
                            self.sendElementState(self.elements.motionAttitudeX)
                            self.sendElementState(self.elements.motionAttitudeZ)
                            self.sendElementState(self.elements.motionAttitudeW)
                        }
                        
                        self.elements.motionUserAccelerationX.value = Float((deviceMotionData?.userAcceleration.x)!)
                        self.elements.motionUserAccelerationY.value = Float((deviceMotionData?.userAcceleration.y)!)
                        self.elements.motionUserAccelerationZ.value = Float((deviceMotionData?.userAcceleration.z)!)
                        
                        // Send data on the custom accelerometer channels
                        if VgcManager.enableMotionUserAcceleration {
                            self.sendElementState(self.elements.motionUserAccelerationX)
                            self.sendElementState(self.elements.motionUserAccelerationY)
                            self.sendElementState(self.elements.motionUserAccelerationZ)
                        }
                        
                        // Gravity
                        
                        self.elements.motionGravityX.value = Float((deviceMotionData?.gravity.x)!)
                        self.elements.motionGravityY.value = Float((deviceMotionData?.gravity.y)!)
                        self.elements.motionGravityZ.value = Float((deviceMotionData?.gravity.z)!)
                        
                        if VgcManager.enableMotionGravity {
                            self.sendElementState(self.elements.motionGravityX)
                            self.sendElementState(self.elements.motionGravityY)
                            self.sendElementState(self.elements.motionGravityZ)
                        }
                        
                        // Rotation Rate
                        
                        self.elements.motionRotationRateX.value = Float((deviceMotionData?.rotationRate.x)!)
                        self.elements.motionRotationRateY.value = Float((deviceMotionData?.rotationRate.y)!)
                        self.elements.motionRotationRateZ.value = Float((deviceMotionData?.rotationRate.z)!)
                        
                        //print("Rotation: X \( Float((deviceMotionData?.rotationRate.x)!)), Y: \(Float((deviceMotionData?.rotationRate.y)!)), Z: \(Float((deviceMotionData?.rotationRate.z)!))")
                        
                        if VgcManager.enableMotionRotationRate {
                            self.sendElementState(self.elements.motionRotationRateX)
                            self.sendElementState(self.elements.motionRotationRateY)
                            self.sendElementState(self.elements.motionRotationRateZ)
                        }
                    })
                    
                } else if self.manager.accelerometerAvailable {
                    
                    print("Starting accelerometer detection (for the Watch)")
                    self.manager.accelerometerUpdateInterval = NSTimeInterval(self.updateInterval)
                    self.manager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (accelerometerData, error) -> Void in
                        
                        /*
                        //print("Device Motion: \(deviceMotionData!)")
                        
                        motionAttitudeY.value = Float((deviceMotionData?.attitude.quaternion.y)!)
                        motionAttitudeX.value = Float((deviceMotionData?.attitude.quaternion.x)!)
                        motionAttitudeZ.value = Float((deviceMotionData?.attitude.quaternion.z)!)
                        motionAttitudeW.value = Float((deviceMotionData?.attitude.quaternion.w)!)
                        
                        // Send data on the custom accelerometer channels
                        if enableAttitude {
                        self.sendElementValueToBridge(motionAttitudeY)
                        self.sendElementValueToBridge(motionAttitudeX)
                        self.sendElementValueToBridge(motionAttitudeZ)
                        self.sendElementValueToBridge(motionAttitudeW)
                        }
                        */
                        self.elements.motionUserAccelerationX.value = Float((accelerometerData?.acceleration.x)!)
                        self.elements.motionUserAccelerationY.value = Float((accelerometerData?.acceleration.y)!)
                        self.elements.motionUserAccelerationZ.value = Float((accelerometerData?.acceleration.z)!)
                        
                        print("Sending accelerometer: \(accelerometerData?.acceleration.x) \(accelerometerData?.acceleration.y) \(accelerometerData?.acceleration.z)")
                        
                        // Send data on the custom accelerometer channels
                        if VgcManager.enableMotionUserAcceleration {
                            self.sendElementState(self.elements.motionUserAccelerationX)
                            self.sendElementState(self.elements.motionUserAccelerationY)
                            self.sendElementState(self.elements.motionUserAccelerationZ)
                        }
                        
                        /*
                        // Rotation Rate
                        
                        motionRotationRateX.value = Float((deviceMotionData?.rotationRate.x)!)
                        motionRotationRateY.value = Float((deviceMotionData?.rotationRate.y)!)
                        motionRotationRateZ.value = Float((deviceMotionData?.rotationRate.z)!)
                        
                        print("Rotation: X \( Float((deviceMotionData?.rotationRate.x)!)), Y: \(Float((deviceMotionData?.rotationRate.y)!)), Z: \(Float((deviceMotionData?.rotationRate.z)!))")
                        
                        if enableRotationRate {
                        self.sendElementValueToBridge(motionRotationRateX)
                        self.sendElementValueToBridge(motionRotationRateY)
                        self.sendElementValueToBridge(motionRotationRateZ)
                        }
                        
                        // Gravity
                        
                        motionGravityX.value = Float((deviceMotionData?.gravity.x)!)
                        motionGravityY.value = Float((deviceMotionData?.gravity.y)!)
                        motionGravityZ.value = Float((deviceMotionData?.gravity.z)!)
                        
                        if enableGravity {
                        self.sendElementValueToBridge(motionGravityX)
                        self.sendElementValueToBridge(motionGravityY)
                        self.sendElementValueToBridge(motionGravityZ)
                        }
                        */
                    })
                    
                }
                
            }
        #endif // End of block out of motion for tvOS and OSX
    }

    public func stop() {
        #if os(iOS) || os(watchOS)
            print("Stopping motion detection")
            manager.stopDeviceMotionUpdates()
            active = false
        #endif
    }
    
    func sendElementState(element: Element) {
        
        #if os(iOS)
            VgcManager.peripheral.sendElementState(element)
        #endif
        
        #if os(watchOS)
            watchConnectivity.sendElementValueToBridge(element)
        #endif
        
    }

 }
#endif
