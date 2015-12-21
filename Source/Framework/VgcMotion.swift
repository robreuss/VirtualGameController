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
    private let elements = VgcManager.elements
    var controller: VgcController!
    #endif
    
    #if os(watchOS)
    public var watchConnectivity: VgcWatchConnectivity!
    public var elements: Elements!
    #endif
    
    public var deviceSupportsMotion: Bool!
    
    public let manager = CMMotionManager()
    
    public var active: Bool = false
    
    ///
    /// Don't enable these unless they are really needed because they produce
    /// tons of data to be transmitted and clog the channels.
    ///
    public var enableUserAcceleration = true
    public var enableRotationRate = true
    public var enableAttitude = true
    public var enableGravity = true
    
    public var enableLowPassFilter = true
    public var enableAdaptiveFilter = true
    public var cutOffFrequency: Double = 5.0
    var filterConstant: Double!
    
    ///
    /// System can handle 60 updates/sec but only if a subset of motion factors are enabled,
    /// not all four.  If all four inputs are needed, update frequency should be reduced.
    ///
    public var updateInterval = 1.0 / 60 {
        didSet {
            manager.deviceMotionUpdateInterval = updateInterval
            setupFilterConstant()
        }
    }
    
    func setupFilterConstant()
    {
        
        let dt = updateInterval
        let RC = 1.0 / cutOffFrequency
        filterConstant = dt / (dt + RC)
        
    }
    
    public func start() {
  
        #if os(iOS) || os(watchOS)
            
            vgcLogDebug("Attempting to start motion detection")
            
            #if os(iOS)
                if !deviceIsTypeOfBridge() {
                    if  VgcManager.peripheral.haveConnectionToCentral == false {
                        vgcLogDebug("Not starting motion because no connection")
                        return
                    }
                }
                if VgcManager.appRole == .EnhancementBridge {
                    if VgcController.enhancedController.peripheral.haveConnectionToCentral == false {
                        vgcLogDebug("Not starting motion because no connection")
                        return
                    }
                }
            #endif
            
            // No need to start if already active
            if manager.deviceMotionActive {
                vgcLogDebug("Not starting motion because already active")
                return
            }
            
            vgcLogDebug("Device supports: \(self.deviceSupportsMotion), motion available: \(self.manager.deviceMotionAvailable), accelerometer available: \(self.manager.accelerometerAvailable)")
            
            if deviceIsTypeOfBridge() || self.deviceSupportsMotion == true {
                
                active = true
                
                // iOS supports device motion, but the watch only supports direct accelerometer data
                if self.manager.deviceMotionAvailable {
                    
                    setupFilterConstant()
                    
                    //let motionQueue = NSOperationQueue()
                    
                    vgcLogDebug("Starting device motion updating")
                    manager.deviceMotionUpdateInterval = NSTimeInterval(updateInterval)
                    
                    manager.startDeviceMotionUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (deviceMotionData, error) -> Void in
                        
                        if error != nil {
                            vgcLogDebug("Got device motion error: \(error)")
                        }
                        
                        var x, y, z, w: Double
                        
                        // Send data on the custom accelerometer channels
                        if self.enableAttitude {
                            
                            (x, y, z, w) = self.filterX(((deviceMotionData?.attitude.quaternion.x)!), y: ((deviceMotionData?.attitude.quaternion.y)!), z: ((deviceMotionData?.attitude.quaternion.z)!), w: ((deviceMotionData?.attitude.quaternion.w)!))
                            
                            //vgcLogDebug("Old double: \(deviceMotionData?.attitude.quaternion.x), new float: \(x)")
                            
                            self.elements.motionAttitudeX.value = Float(x)
                            self.elements.motionAttitudeY.value = Float(y)
                            self.elements.motionAttitudeZ.value = Float(z)
                            self.elements.motionAttitudeW.value = Float(w)
                            
                            self.sendElementState(self.elements.motionAttitudeY)
                            self.sendElementState(self.elements.motionAttitudeX)
                            self.sendElementState(self.elements.motionAttitudeZ)
                            self.sendElementState(self.elements.motionAttitudeW)
                        }
                    
                        
                        // Send data on the custom accelerometer channels
                        if self.enableUserAcceleration {
                            
                            (x, y, z, w) = self.filterX(((deviceMotionData?.userAcceleration.x)!), y: ((deviceMotionData?.userAcceleration.y)!), z: ((deviceMotionData?.userAcceleration.z)!), w: 0)
            
                            self.elements.motionUserAccelerationX.value = Float(x)
                            self.elements.motionUserAccelerationY.value = Float(y)
                            self.elements.motionUserAccelerationZ.value = Float(z)
                            
                            self.sendElementState(self.elements.motionUserAccelerationX)
                            self.sendElementState(self.elements.motionUserAccelerationY)
                            self.sendElementState(self.elements.motionUserAccelerationZ)
                        }
                        
                        // Gravity
                        
                        if self.enableGravity {
                            
                            (x, y, z, w) = self.filterX(((deviceMotionData?.gravity.x)!), y: ((deviceMotionData?.gravity.y)!), z: ((deviceMotionData?.gravity.z)!), w: 0)
                           
                            self.elements.motionGravityX.value = Float(x)
                            self.elements.motionGravityY.value = Float(y)
                            self.elements.motionGravityZ.value = Float(z)
                            
                            self.sendElementState(self.elements.motionGravityX)
                            self.sendElementState(self.elements.motionGravityY)
                            self.sendElementState(self.elements.motionGravityZ)
                        }
                        
                        // Rotation Rate
               
                        if self.enableRotationRate {
                            
                            (x, y, z, w) = self.filterX(((deviceMotionData?.rotationRate.x)!), y: ((deviceMotionData?.rotationRate.y)!), z: ((deviceMotionData?.rotationRate.z)!), w: 0)
                            
                            self.elements.motionRotationRateX.value = Float(x)
                            self.elements.motionRotationRateY.value = Float(y)
                            self.elements.motionRotationRateZ.value = Float(z)
                            
                            self.sendElementState(self.elements.motionRotationRateX)
                            self.sendElementState(self.elements.motionRotationRateY)
                            self.sendElementState(self.elements.motionRotationRateZ)
                        }
                    })
                    
                } else if self.manager.accelerometerAvailable {
                    
                    vgcLogDebug("Starting accelerometer detection (for the Watch)")
                    self.manager.accelerometerUpdateInterval = NSTimeInterval(self.updateInterval)
                    self.manager.startAccelerometerUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (accelerometerData, error) -> Void in
                        
                        /*
                        //vgcLogDebug("Device Motion: \(deviceMotionData!)")
                        
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
                        
                        vgcLogDebug("Sending accelerometer: \(accelerometerData?.acceleration.x) \(accelerometerData?.acceleration.y) \(accelerometerData?.acceleration.z)")
                        
                        // Send data on the custom accelerometer channels
                        //if VgcManager.peripheral.motion.enableUserAcceleration {
                            self.sendElementState(self.elements.motionUserAccelerationX)
                            self.sendElementState(self.elements.motionUserAccelerationY)
                            self.sendElementState(self.elements.motionUserAccelerationZ)
                        //}
                        
                        /*
                        // Rotation Rate
                        
                        motionRotationRateX.value = Float((deviceMotionData?.rotationRate.x)!)
                        motionRotationRateY.value = Float((deviceMotionData?.rotationRate.y)!)
                        motionRotationRateZ.value = Float((deviceMotionData?.rotationRate.z)!)
                        
                        vgcLogDebug("Rotation: X \( Float((deviceMotionData?.rotationRate.x)!)), Y: \(Float((deviceMotionData?.rotationRate.y)!)), Z: \(Float((deviceMotionData?.rotationRate.z)!))")
                        
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
            vgcLogDebug("Stopping motion detection")
            manager.stopDeviceMotionUpdates()
            active = false
        #endif
    }
    
    func sendElementState(element: Element) {
        
        #if os(iOS)
            if deviceIsTypeOfBridge() {
                controller.peripheral.sendElementState(element)
            } else {
                VgcManager.peripheral.sendElementState(element)
            }

        #endif
        
        #if os(watchOS)
            watchConnectivity.sendElementState(element)
        #endif
        
    }
    
    // Filter functions
    func Norm(x: Double, y: Double, z: Double) -> Double
    {
        return sqrt(x * x + y * y + z * z);
    }
    
    func Clamp(v: Double, min: Double, max: Double) -> Double
    {
        if(v > max) { return max } else if (v < min) { return min } else { return v }
    }
    
    let kAccelerometerMinStep =	0.02
    let kAccelerometerNoiseAttenuation = 3.0
    
    func filterX(x: Double, y: Double, z: Double, w: Double) -> (Double, Double, Double, Double) {

        if enableLowPassFilter {
            
            var alpha = filterConstant;
            
            if enableAdaptiveFilter {
                let d = Clamp(fabs(Norm(x, y: y, z: z) - Norm(x, y: y, z: z)) / kAccelerometerMinStep - 1.0, min: 0.0, max: 1.0)
                alpha = (1.0 - d) * filterConstant / kAccelerometerNoiseAttenuation + d * filterConstant
            }
            return (x * alpha + x * (1.0 - alpha), y * alpha + y * (1.0 - alpha), z * alpha + z * (1.0 - alpha), w)
        } else {
            return (x, y, z, w)
        }
    }

 }
#endif
