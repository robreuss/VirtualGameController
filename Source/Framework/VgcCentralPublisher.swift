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

internal class VgcCentralPublisher: NSObject, NSNetServiceDelegate, NSStreamDelegate {
    
    var localService: NSNetService!
    var registeredName: String!
    var streamOpenCount: Int!
    var haveConnectionToPeripheral: Bool
    #if os(iOS)
    var centralPublisherWatch: CentralPublisherWatch!
    #endif
    
    override init() {
        
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
        
        self.haveConnectionToPeripheral = true
        
        print("A peripheral has connected to us!")
        
        // We initalize the controller, but wait for device info before we add it to the
        // controllers array or send the didConnect notification
        let controller = VgcController()
        controller.centralPublisher = self
        controller.setupNetworkService(service, inputStream: inputStream, outputStream: outputStream)
        
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
        print("CENTRAL: netService didNotResolve")
    }
    
    internal func netServiceDidResolveAddress(sender: NSNetService) {
        print("CENTRAL: netServiceDidResolveAddress")
    }
    
    internal func netServiceDidStop(sender: NSNetService) {
        print("CENTRAL: netServiceDidStop")
        self.haveConnectionToPeripheral = false
    }
    
    
}
