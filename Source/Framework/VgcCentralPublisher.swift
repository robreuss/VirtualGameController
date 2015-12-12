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

struct  VgcPendingStream {
    
    var inputStream: NSInputStream
    var outputStream: NSOutputStream
    var streamer: VgcStreamer
    
}

internal class VgcCentralPublisher: NSObject, NSNetServiceDelegate, NSStreamDelegate {
    
    var localService: NSNetService!
    var remoteService: NSNetService!
    var registeredName: String!
    var streamOpenCount: Int!
    var haveConnectionToPeripheral: Bool
    var unusedInputStream: NSInputStream!
    var unusedOutputStream: NSOutputStream!
    var streamMatchingTimeout: NSDate!
    #if os(iOS)
    var centralPublisherWatch: CentralPublisherWatch!
    #endif
    
    override init() {
        
        print("Initializing Central Publisher")
        
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
        
        #if os(iOS)
            self.centralPublisherWatch = CentralPublisherWatch()
        #endif
    }
    
    // So that peripherals will be able to see us over NetServices
    func publishService() {
        print("Publishing NetService service to listen for Peripherals on \(self.localService.name)")
        self.localService.publishWithOptions(.ListenForConnections)
        #if os(iOS)
            centralPublisherWatch.scanForWatchController()
        #endif
    }
    
    func unpublishService() {
        print("Central unpublishing service")
        localService.stop()
    }
    
    internal func netService(service: NSNetService, didAcceptConnectionWithInputStream inputStream: NSInputStream, outputStream: NSOutputStream) {
        
        remoteService = service
        remoteService.resolveWithTimeout(10.0)

        self.haveConnectionToPeripheral = true
        
        // Only a certain amount of time is permitted for the second stream request to arrive, and
        // otherwise the stream is treated as the initial stream again
        if streamMatchingTimeout != nil && streamMatchingTimeout.timeIntervalSinceNow > 0.1 {
            print("ERROR: Clearing initial stream information because of stream matching timeout")
            unusedInputStream = nil
            unusedOutputStream = nil
        }
        
        // This delegate method will be called twice, once for large and once for small data.  We only setup the network services
        // once we receive both requests.
        if unusedInputStream != nil {

            print("A peripheral has connected with second set of streams (Input: \(inputStream), Output: \(outputStream))")

            // We initalize the controller, but wait for device info before we add it to the
            // controllers array or send the didConnect notification
            let controller = VgcController()
            controller.centralPublisher = self
            controller.openstreams(.LargeData, inputStream: unusedInputStream, outputStream: unusedOutputStream)
            controller.openstreams(.SmallData, inputStream: inputStream, outputStream: outputStream)
            
            unusedOutputStream = nil
            unusedInputStream = nil
            
            streamMatchingTimeout = nil

        } else {
            
            print("A peripheral has connected with first set of streams (Input: \(inputStream), Output: \(outputStream))")
            
            print("Setting first set of new streams to temporary vars")
            unusedInputStream = inputStream
            unusedOutputStream = outputStream
            
            streamMatchingTimeout = NSDate()
            
        }
    }
    
    internal func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        print("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    internal func netServiceDidPublish(sender: NSNetService) {
        if deviceIsTypeOfBridge() {
            print("Bridge is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            print("Central is now published on: \(sender.domain + sender.type + sender.name)")
        }
        self.registeredName = sender.name
    }
    
    internal func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        print("Central net service did not publish, error: \(errorDict), registered name: \(self.registeredName), server name: \(self.localService.name)")
        print("Republishing net service")
        unpublishService()
        publishService()
    }
    
    internal func netServiceWillPublish(sender: NSNetService) {
        print("NetService will be published")
    }
    
    internal func netServiceWillResolve(sender: NSNetService) {
        print("CENTRAL: netServiceWillResolve")
    }
    
    internal func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        print("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    internal func netServiceDidResolveAddress(sender: NSNetService) {
        print("CENTRAL: netServiceDidResolveAddress")
    }
    
    internal func netServiceDidStop(sender: NSNetService) {
        print("CENTRAL: netServiceDidStop")
        self.haveConnectionToPeripheral = false
    }
    
    
}
