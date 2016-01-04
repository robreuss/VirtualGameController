//
//  VgcCentralPublisher.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation
#if os(iOS) || os(tvOS) // Need this only for UIDevice
    import UIKit
#endif
#if os(iOS) || os(OSX) || os(tvOS)
    import GameController
#endif

#if !os(watchOS)

@objc internal protocol VgcPendingStreamDelegate {
    
    func testForMatchingStreams()
    
}

class VgcPendingStream: NSObject, VgcStreamerDelegate {
    
    weak var delegate: VgcPendingStreamDelegate?
    var createTime = NSDate()
    var inputStream: NSInputStream
    var outputStream: NSOutputStream
    var streamer: VgcStreamer!
    var deviceInfo: DeviceInfo!
    
    init(inputStream: NSInputStream, outputStream: NSOutputStream, delegate: VgcPendingStreamDelegate) {
        
        self.delegate = delegate
        self.inputStream = inputStream
        self.outputStream = outputStream
        
        super.init()
    }
    
    
    func disconnect() {
        vgcLogError("Got disconnect from pending stream streamer")
    }

    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: NSData) {
        
        let element = VgcManager.elements.elementFromIdentifier(elementIdentifier)
        
        if element.type == .DeviceInfoElement {
            
            element.valueAsNSData = elementValue
            NSKeyedUnarchiver.setClass(DeviceInfo.self, forClassName: "DeviceInfo")
            deviceInfo = (NSKeyedUnarchiver.unarchiveObjectWithData(element.valueAsNSData) as? DeviceInfo)!
            
            delegate?.testForMatchingStreams()
            
        }
    }
    
    func openstreams() {
        
        vgcLogDebug("Opening pending streams")

        outputStream.delegate = streamer
        outputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        outputStream.open()
        
        inputStream.delegate = streamer
        inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
        inputStream.open()
        
    }

    // Make class hashable - function to make it equatable appears below outside the class definition
    override var hashValue: Int {
        return inputStream.hashValue
    }

}

// Make class equatable
func ==(lhs: VgcPendingStream, rhs: VgcPendingStream) -> Bool {
    return lhs.inputStream.hashValue == rhs.inputStream.hashValue
}


internal class VgcCentralPublisher: NSObject, NSNetServiceDelegate, NSStreamDelegate, VgcPendingStreamDelegate {
    
    var localService: NSNetService!
    var remoteService: NSNetService!
    var registeredName: String!
    var haveConnectionToPeripheral: Bool
    var unusedInputStream: NSInputStream!
    var unusedOutputStream: NSOutputStream!
    var streamMatchingTimer: NSTimer!
    var pendingStreams = Set<VgcPendingStream>()
    
    override init() {
        
        vgcLogDebug("Initializing Central Publisher")
        
        self.haveConnectionToPeripheral = false
        
        super.init()
        
        // Note, for some reason OSX requires that the centralServiceName is force unwrapped, but it does not compile that way
        // on iOS, hence these two conditional alternatives.
        #if os(OSX)
            if deviceIsTypeOfBridge() {
                self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeBridge, name: VgcManager.centralServiceName!, port: 0)
            } else {
                self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeCentral, name: VgcManager.centralServiceName!, port: 0)
                
            }
        #else
            if deviceIsTypeOfBridge() {
                self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeBridge, name: VgcManager.centralServiceName, port: 0)
            } else {
                self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeCentral, name: VgcManager.centralServiceName, port: 0)
                
            }
        #endif
        
        self.localService.delegate = self
        self.localService.includesPeerToPeer = VgcManager.includesPeerToPeer

    }
    
    // So that peripherals will be able to see us over NetServices
    func publishService() {
        vgcLogDebug("Publishing NetService service to listen for Peripherals on \(self.localService.name)")
        self.localService.publishWithOptions(.ListenForConnections)
    }
    
    func unpublishService() {
        vgcLogDebug("Central unpublishing service")
        localService.stop()
    }
    
    func updateMatchingStreamTimer() {
        
        if pendingStreams.count == 0 && streamMatchingTimer.valid {
            vgcLogDebug("Invalidating matching stream timer")
            streamMatchingTimer.invalidate()
            streamMatchingTimer = nil
        } else if pendingStreams.count > 0 && streamMatchingTimer == nil {
            vgcLogDebug("Setting matching stream timer")
            streamMatchingTimer = NSTimer.scheduledTimerWithTimeInterval(VgcManager.maxTimeForMatchingStreams, target: self, selector: "testForMatchingStreams", userInfo: nil, repeats: false)
        }
        
    }
    
    let lockQueuePendingStreams = dispatch_queue_create("net.simplyformed.lockQueuePendingStreams", nil)
    
    func testForMatchingStreams() {
        
        var pendingStream1: VgcPendingStream! = nil
        var pendingStream2: VgcPendingStream! = nil
        
        dispatch_sync(lockQueuePendingStreams) {
            
            if self.pendingStreams.count > 0 { vgcLogDebug("Testing for matching streams among \(self.pendingStreams.count) pending streams") }
            
            for comparisonStream in self.pendingStreams {
                if pendingStream1 == nil {
                    for testStream in self.pendingStreams {
                        if pendingStream1 == nil && (testStream.deviceInfo != nil && comparisonStream.deviceInfo != nil) && (testStream.deviceInfo.deviceUID == comparisonStream.deviceInfo.deviceUID) && testStream != comparisonStream {
                            vgcLogDebug("Found matching stream for deviceUID: \(comparisonStream.deviceInfo.deviceUID)")
                            pendingStream1 = testStream
                            pendingStream2 = comparisonStream
                            continue
                        }
                    }
                }
                
                // Test primarily for the situation where we only get one of the two required
                // stream sets, and therefore there are potential orphans
                if fabs(comparisonStream.createTime.timeIntervalSinceNow) > VgcManager.maxTimeForMatchingStreams {
                    vgcLogDebug("Removing expired pending streams and closing")
                    comparisonStream.inputStream.close()
                    comparisonStream.outputStream.close()
                    self.pendingStreams.remove(comparisonStream)
                }
            }
            
            if pendingStream1 != nil {
                
                self.pendingStreams.remove(pendingStream1)
                self.pendingStreams.remove(pendingStream2)
                
                vgcLogDebug("\(self.pendingStreams.count) pending streams remain in set")
                
                let controller = VgcController()
                controller.centralPublisher = self
                pendingStream1.streamer.delegate = controller
                pendingStream2.streamer.delegate = controller
                controller.openstreams(.LargeData, inputStream: pendingStream1.inputStream, outputStream: pendingStream1.outputStream, streamStreamer: pendingStream1.streamer)
                controller.openstreams(.SmallData, inputStream: pendingStream2.inputStream, outputStream: pendingStream2.outputStream, streamStreamer: pendingStream2.streamer)
                
                // Use of pendingStream1 is arbitrary - both streams have same deviceInfo
                controller.deviceInfo = pendingStream1.deviceInfo
                
                pendingStream1.streamer = nil
                pendingStream2.streamer = nil 
            }

        }

        updateMatchingStreamTimer()

    }
    
    internal func netService(service: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {

        vgcLogDebug("Assigning input/output streams to pending stream object")
        
        self.haveConnectionToPeripheral = true
        
        let pendingStream = VgcPendingStream(inputStream: inputStream, outputStream: outputStream, delegate: self)

        pendingStream.streamer = VgcStreamer(delegate: pendingStream, delegateName:"Central Publisher")

        dispatch_sync(lockQueuePendingStreams) {
            self.pendingStreams.insert(pendingStream)
        }
        pendingStream.openstreams()
        
        updateMatchingStreamTimer()
        
    }
    
    internal func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        vgcLogDebug("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    internal func netServiceDidPublish(sender: NSNetService) {
        if deviceIsTypeOfBridge() {
            vgcLogDebug("Bridge is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            vgcLogDebug("Central is now published on: \(sender.domain + sender.type + sender.name)")
        }
        self.registeredName = sender.name
    }
    
    internal func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        vgcLogDebug("Central net service did not publish, error: \(errorDict), registered name: \(self.registeredName), server name: \(self.localService.name)")
        vgcLogDebug("Republishing net service")
        unpublishService()
        publishService()
    }
    
    internal func netServiceWillPublish(sender: NSNetService) {
        vgcLogDebug("NetService will be published")
    }
    
    internal func netServiceWillResolve(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceWillResolve")
    }
    
    internal func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        vgcLogDebug("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    internal func netServiceDidResolveAddress(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceDidResolveAddress")
    }
    
    internal func netServiceDidStop(sender: NSNetService) {
        vgcLogDebug("CENTRAL: netServiceDidStop")
        self.haveConnectionToPeripheral = false
    }
    
    
}

#endif
