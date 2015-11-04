//
//  VgcPedometer.swift
//  
//
//  Created by Rob Reuss on 10/4/15.
//
//

import Foundation
#if !(os(tvOS)) && !(os(OSX))
import CoreMotion
    
struct ActivityType : OptionSetType {
    let rawValue: Int
    
    static let Stationary  = ActivityType(rawValue: 0)
    static let Walking     = ActivityType(rawValue: 1 << 0)
    static let Running     = ActivityType(rawValue: 1 << 1)
    static let Automotive  = ActivityType(rawValue: 1 << 2)
    static let Cycling     = ActivityType(rawValue: 1 << 3)
    static let Unknown     = ActivityType(rawValue: 1 << 4)
    
}

public class VgcActivity {
    
    let cmActivityManager = CMMotionActivityManager()
    let pedometer = CMPedometer()
    
    #if os(watchOS)
    var watchConnectivity: VgcWatchConnectivity!
    #endif
    
    func sendElementState(element: Element) {
        
        #if os(iOS)
            VgcManager.peripheral.sendElementState(element)
        #endif
        
        #if os(watchOS)
            watchConnectivity.sendElementValueToBridge(element)
        #endif
        
    }
    
    public func start() {
        
        return
        
        print("Pedometer is starting")

        if(CMMotionActivityManager.isActivityAvailable()){
        
            cmActivityManager.startActivityUpdatesToQueue(NSOperationQueue.mainQueue(), withHandler: { (data) -> Void in
                
                /*
                var activities: [ActivityType] = []
                if data!.stationary == true { activities.append(.Stationary) }
                if data!.walking    == true { activities.append(.Walking) }
                if data!.running    == true { activities.append(.Running) }
                if data!.automotive == true { activities.append(.Automotive) }
                if data!.cycling    == true { activities.append(.Cycling) }
                if data!.unknown    == true { activities.append(.Unknown) }
    */
                var activityTypeBitMask: Int = 0
                
                if data!.stationary == true { activityTypeBitMask += ActivityType.Stationary.rawValue }
                if data!.walking == true    { activityTypeBitMask += ActivityType.Walking.rawValue }
                if data!.running == true    { activityTypeBitMask += ActivityType.Running.rawValue }
                if data!.automotive == true { activityTypeBitMask += ActivityType.Automotive.rawValue }
                if data!.cycling == true    { activityTypeBitMask += ActivityType.Cycling.rawValue }
                if data!.unknown == true    { activityTypeBitMask += ActivityType.Unknown.rawValue }
                
                print("Activity Type Raw: \(activityTypeBitMask)")
                
                let activityTypes = ActivityType(rawValue: activityTypeBitMask)
                if activityTypes.contains(.Stationary)  { print("Stationary") }
                if activityTypes.contains(.Walking)     { print("Walking") }
                if activityTypes.contains(.Running)     { print("Running") }
                if activityTypes.contains(.Automotive)  { print("Automotive") }
                if activityTypes.contains(.Cycling)     { print("Cycling") }
                if activityTypes.contains(.Unknown)     { print("Unknown") }
                
                elements.activityType.value = activityTypeBitMask
                self.sendElementState(elements.activityType)
                
            })
        }

        if(CMPedometer.isStepCountingAvailable()){

            self.pedometer.startPedometerUpdatesFromDate(NSDate(), withHandler: { (data, error) -> Void in
                
                print("Number of steps: \(data!.numberOfSteps)")
                elements.activitySteps.value = data!.numberOfSteps
                self.sendElementState(elements.activitySteps)
                
                if data!.distance != nil {
                    elements.activityDistance.value = data!.distance!.floatValue
                    self.sendElementState(elements.activityDistance)
                }
                
                if data!.currentPace != nil {
                    elements.activityPace.value = data!.currentPace!.floatValue
                    self.sendElementState(elements.activityPace)
                }
                if data!.currentCadence != nil {
                    elements.activityCadence.value = data!.currentCadence!.floatValue
                    self.sendElementState(elements.activityCadence)
                }
                
                if data!.floorsAscended != nil {
                    elements.activityFloors.value = data!.floorsAscended!.floatValue
                    self.sendElementState(elements.activityFloors)
                }

            })

        }
    }
    
    public func stop() {
        print("Stopping activity detection")
        pedometer.stopPedometerUpdates()
        cmActivityManager.stopActivityUpdates()
    }
}
    
#endif
