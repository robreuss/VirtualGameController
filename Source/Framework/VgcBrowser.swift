//
//  VgcPeripheralNetService.swift
//
//
//  Created by Rob Reuss on 10/1/15.
//
//

import Foundation

#if os(iOS)
    import UIKit
#endif

#if os(iOS) || os(OSX) || os(tvOS)
    import GameController // Needed only because of a reference to playerIndex
#endif

// Set deviceName in a platform specific way
#if os(iOS) || os(tvOS)
let deviceName = UIDevice.currentDevice().name
    public let peripheralBackgroundColor = UIColor(red: 0.76, green: 0.76, blue: 0.76, alpha: 1)
#endif

#if os(OSX)
let deviceName = NSHost.currentHost().localizedName!
    public let peripheralBackgroundColor = NSColor(red: 0.76, green: 0.76, blue: 0.76, alpha: 1)
#endif

#if !os(watchOS)

// MARK: NetService Peripheral Management

class VgcBrowser: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate, NSStreamDelegate, VgcStreamerDelegate {

    var elements: Elements!
    var peripheral: Peripheral!
    var connectedVgcService: VgcService!
    var localService: NSNetService!
    var inputStream: [StreamDataType: NSInputStream] = [:]
    var outputStream: [StreamDataType: NSOutputStream] = [:]
    var registeredName: String!
    var bridgeBrowser: NSNetServiceBrowser!
    var centralBrowser: NSNetServiceBrowser!
    var browsing = false
    var streamer: [StreamDataType: VgcStreamer] = [:]
    var serviceLookup = Dictionary<NSNetService, VgcService>()
    
    init(peripheral: Peripheral) {
        
        super.init()
        
        self.peripheral = peripheral
        
        elements = VgcManager.elements
        
        self.streamer[.LargeData] = VgcStreamer(delegate: self, delegateName: "Browser")
        self.streamer[.SmallData] = VgcStreamer(delegate: self, delegateName: "Browser")
        
        vgcLogDebug("Setting up NSNetService for browsing")
        
        self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeCentral, name: deviceName, port: 0)
        self.localService.delegate = self
        self.localService.includesPeerToPeer = VgcManager.includesPeerToPeer
        
    }
    
    func closeStream(streamDataType: StreamDataType) {
        
        if inputStream[streamDataType] != nil { inputStream[streamDataType]!.close() }
        if outputStream[streamDataType] != nil { outputStream[streamDataType]!.close() }
        
    }
    
    func closeStreams() {
        
        vgcLogDebug("Closing streams")
        
        closeStream(.LargeData)
        closeStream(.SmallData)
        
        peripheral.haveOpenStreamsToCentral = false
        
    }
    
    // This is a callback from the streamer
    func disconnect() {
        vgcLogDebug("Browser received disconnect")
        closeStreams()
        browsing = false
        if connectedVgcService != nil { peripheral.lostConnectionToCentral(connectedVgcService) }
        connectedVgcService = nil
        browseForCentral()
    }
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: NSData) {
        
        // Get the element in the message using the hash value reference
        guard let element = elements.elementFromIdentifier(elementIdentifier) else {
            vgcLogError("Received unknown element identifier: \(elementIdentifier) from \(connectedVgcService.fullName)")
            return
        }
        
        element.valueAsNSData = elementValue
        
        switch (element.type) {
            
        case .SystemMessage:
            
            let systemMessageType = SystemMessages(rawValue: Int(element.value as! NSNumber))
            
            vgcLogDebug("Central sent system message: \(systemMessageType!.description) to \(connectedVgcService.fullName)")
            
            if systemMessageType == .ConnectionAcknowledgement {
                
                dispatch_async(dispatch_get_main_queue()) {

                    if self.peripheral.connectionAcknowledgementWaitTimeout != nil { self.peripheral.connectionAcknowledgementWaitTimeout.invalidate() }
                    
                    self.peripheral.haveConnectionToCentral = true
                    
                    NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralDidConnectNotification, object: nil)
                    
                }
                
            } else {
            
                NSNotificationCenter.defaultCenter().postNotificationName(VgcSystemMessageNotification, object: systemMessageType!.rawValue)
                
            }
            
            break
            
        case .PeripheralSetup:
            
            NSKeyedUnarchiver.setClass(VgcPeripheralSetup.self, forClassName: "VgcPeripheralSetup")
            VgcManager.peripheralSetup = (NSKeyedUnarchiver.unarchiveObjectWithData(element.valueAsNSData) as! VgcPeripheralSetup)

            vgcLogDebug("Central sent peripheral setup: \(VgcManager.peripheralSetup)")

            NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralSetupNotification, object: nil)

            break
            
        case .VibrateDevice:
            
            peripheral.vibrateDevice()
            
            break
            
        case .PlayerIndex:

            let playerIndex = Int(element.value as! NSNumber)
            peripheral.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
            
            if deviceIsTypeOfBridge(){
                
                self.peripheral.controller.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex)!
                
            }
            NSNotificationCenter.defaultCenter().postNotificationName(VgcNewPlayerIndexNotification, object: playerIndex)
            
        default:
          
            // Call the handler set on the global object
            if let handler = element.valueChangedHandlerForPeripheral {
                handler(element)
            }
            
            #if os(iOS)
                if VgcManager.peripheral.watch != nil { VgcManager.peripheral.watch.sendElementState(element) }
            #endif
            
        }
        
        // If we're a bridge, send along the value to the Central
        if deviceIsTypeOfBridge() && element.type != .PlayerIndex {
            
            //peripheral.browser.sendElementStateOverNetService(element)
            peripheral.controller.sendElementStateToPeripheral(element)
            
        }

    }
    
    // Used to disconnect a peripheral from a center
    func disconnectFromCentral() {
        if connectedVgcService == nil { return }
        vgcLogDebug("Browser sending system message Disconnect)")
        elements.systemMessage.value = SystemMessages.Disconnect.rawValue
        sendElementStateOverNetService(elements.systemMessage)
        closeStreams()
    }
    
    // This is triggered by the Streamer if it receives a malformed message.  We just log it here.
    func sendInvalidMessageSystemMessage() {
        vgcLogDebug("Peripheral received invalid checksum message from Central")
    }
    
    func sendDeviceInfoElement(let element: Element!) {
        
        if element == nil {
            vgcLogDebug("Browser got attempt to send nil element to \(connectedVgcService.fullName)")
            return
        }
        
        var outputStreamLarge: NSOutputStream!
        var outputStreamSmall: NSOutputStream!
        
        if VgcManager.appRole == .Peripheral {
            outputStreamLarge = self.outputStream[.LargeData]
            outputStreamSmall = self.outputStream[.SmallData]
        } else if deviceIsTypeOfBridge() {
            outputStreamLarge = peripheral.controller.toCentralOutputStream[.LargeData]
            outputStreamSmall = peripheral.controller.toCentralOutputStream[.SmallData]
        }
        
        if peripheral.haveOpenStreamsToCentral {
            streamer[.LargeData]!.writeElement(element, toStream:outputStreamLarge)
            streamer[.SmallData]!.writeElement(element, toStream:outputStreamSmall)
        }
    }

    func sendElementStateOverNetService(let element: Element!) {
        
        if element == nil {
            vgcLogDebug("Browser got attempt to send nil element to \(connectedVgcService.fullName)")
            return
        }
        
        var outputStream: NSOutputStream!
        
        if VgcManager.appRole == .Peripheral {
            if element.dataType == .Data {
                outputStream = self.outputStream[.LargeData]
            } else {
                outputStream = self.outputStream[.SmallData]
            }
        } else if deviceIsTypeOfBridge() {
            if element.dataType == .Data {
                outputStream = peripheral.controller.toCentralOutputStream[.LargeData]
            } else {
                outputStream = peripheral.controller.toCentralOutputStream[.SmallData]
            }
        }
    
        if outputStream == nil {
            if connectedVgcService != nil { vgcLogDebug("\(connectedVgcService.fullName) failed to send element \(element.name) because we don't have an output stream") } else { vgcLogDebug("Failed to send element \(element.name) because we don't have an output stream") }
            return
        }

        // Prevent writes without a connection except deviceInfo
        if element.dataType == .Data {
            if (peripheral.haveConnectionToCentral || element.type == .DeviceInfoElement) && streamer[.LargeData] != nil { streamer[.LargeData]!.writeElement(element, toStream:outputStream) }
        } else {
            if (peripheral.haveConnectionToCentral || element.type == .DeviceInfoElement) && streamer[.SmallData] != nil { streamer[.SmallData]!.writeElement(element, toStream:outputStream) }
        }
       
    }

    func reset() {
        vgcLogDebug("Resetting service browser")
        serviceLookup.removeAll()
    }
    
    func browseForCentral() {
        
        if browsing {
        
            vgcLogDebug("Not browsing for central because already browsing")
            return
        
        }
        
        browsing = true
        
        vgcLogDebug("Searching for Centrals on \(VgcManager.bonjourTypeCentral)")
        centralBrowser = NSNetServiceBrowser()
        centralBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
        centralBrowser.delegate = self
        centralBrowser.searchForServicesOfType(VgcManager.bonjourTypeCentral, inDomain: "local")
        
        // We only searches for bridges if we are not type bridge (bridges don't connect to bridges)
        if !deviceIsTypeOfBridge() {
            vgcLogDebug("Searching for Bridges on \(VgcManager.bonjourTypeBridge)")
            bridgeBrowser = NSNetServiceBrowser()
            bridgeBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
            bridgeBrowser.delegate = self
            bridgeBrowser.searchForServicesOfType(VgcManager.bonjourTypeBridge, inDomain: "local")
        }
    }
    
    func stopBrowsing() {
        vgcLogDebug("Stopping browse for Centrals")
        if centralBrowser != nil { centralBrowser.stop() } else {
            vgcLogError("stopBrowsing() called before browser started")
            return
        }
        vgcLogDebug("Stopping browse for Bridges")
        if !deviceIsTypeOfBridge() { bridgeBrowser.stop() } // Bridges don't browse for Bridges
        vgcLogDebug("Clearing service lookup")
        browsing = false
        if serviceLookup.count > 0 { serviceLookup.removeAll() }
    }
    
    func openStreamsFor(streamDataType: StreamDataType, vgcService: VgcService) {

        vgcLogDebug("Attempting to open \(streamDataType) streams for: \(vgcService.fullName)")
        var success: Bool
        var inStream: NSInputStream?
        var outStream: NSOutputStream?
        success = vgcService.netService.getInputStream(&inStream, outputStream: &outStream)
        if ( !success ) {
            
            vgcLogDebug("Something went wrong connecting to service: \(vgcService.fullName)")
            NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralConnectionFailedNotification, object: nil)
            
        } else {
            
            vgcLogDebug("Successfully opened \(streamDataType) streams to service: \(vgcService.fullName)")
            
            connectedVgcService = vgcService
            
            if deviceIsTypeOfBridge() && peripheral.controller != nil {
                
                peripheral.controller.toCentralOutputStream[streamDataType] = outStream;
                peripheral.controller.toCentralOutputStream[streamDataType]!.delegate = streamer[streamDataType]
                peripheral.controller.toCentralOutputStream[streamDataType]!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                peripheral.controller.toCentralOutputStream[streamDataType]!.open()
                
                peripheral.controller.fromCentralInputStream[streamDataType] = inStream
                peripheral.controller.fromCentralInputStream[streamDataType]!.delegate = streamer[streamDataType]
                peripheral.controller.fromCentralInputStream[streamDataType]!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                peripheral.controller.fromCentralInputStream[streamDataType]!.open()
                
            } else {
                
                outputStream[streamDataType] = outStream;
                outputStream[streamDataType]!.delegate = streamer[streamDataType]
                outputStream[streamDataType]!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                outputStream[streamDataType]!.open()
                
                inputStream[streamDataType] = inStream
                inputStream[streamDataType]!.delegate = streamer[streamDataType]
                inputStream[streamDataType]!.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                inputStream[streamDataType]!.open()
                
            }
            
            // SmallData comes second, so we wait for it before sending deviceInfo
            if streamDataType == .SmallData {
                
                peripheral.gotConnectionToCentral()
                
            }
            
        }
        
    }
    
    func connectToService(vgcService: VgcService) {
       
        if (peripheral.haveConnectionToCentral == true) {
            vgcLogDebug("Refusing to connect to service \(vgcService.fullName) because we already have a connection.")
            return
        }
        
        vgcLogDebug("Attempting to connect to service: \(vgcService.fullName)")
        
        openStreamsFor(.LargeData, vgcService: vgcService)
        openStreamsFor(.SmallData, vgcService: vgcService)
        
        stopBrowsing()
    }
    
    func netServiceBrowserWillSearch(browser: NSNetServiceBrowser) {
        vgcLogDebug("Browser will search")
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        vgcLogDebug("Browser did resolve address")
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        if (service == localService) {
            vgcLogDebug("Ignoring service because it is our own: \(service.name)")
        } else {
            vgcLogDebug("Found service of type \(service.type) at \(service.name)")
            var vgcService: VgcService
            if service.type == VgcManager.bonjourTypeBridge {
                vgcService = VgcService(name: service.name, type:.Bridge, netService: service)
            } else {
                vgcService = VgcService(name: service.name, type:.Central, netService: service)
            }
            
            serviceLookup[service] = vgcService
            
            NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralFoundService, object: vgcService)
            
            if deviceIsTypeOfBridge() && vgcService.type == .Central && connectedVgcService != vgcService { connectToService(vgcService) }
        }
        
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        
        vgcLogDebug("Service was removed: \(service.type) isMainThread: \(NSThread.isMainThread())")
        let vgcService = serviceLookup.removeValueForKey(service)
        vgcLogDebug("VgcService was removed: \(vgcService?.fullName)")
        // If VgcService is nil, it means we already removed the service so we do not send the notification
        if vgcService != nil { NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralLostService, object: vgcService) }
        
    }

    func netServiceBrowserDidStopSearch(browser: NSNetServiceBrowser) {
        browsing = false
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        vgcLogDebug("Net service browser reports error \(errorDict)")
        browsing = false
    }
    
}

#endif
