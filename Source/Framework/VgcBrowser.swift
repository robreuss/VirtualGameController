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

// MARK: NetService Peripheral Management

class VgcBrowser: NSObject, NSNetServiceDelegate, NSNetServiceBrowserDelegate, NSStreamDelegate, VgcStreamerDelegate {

    var elements: Elements!
    var peripheral: Peripheral!
    var connectedVgcService: VgcService!
    var localService: NSNetService!
    var remoteServer: NSNetService!
    var inputStream: NSInputStream!
    var outputStream: NSOutputStream!
    var registeredName: String!
    var streamOpenCount: Int!
    var bridgeBrowser: NSNetServiceBrowser!
    var centralBrowser: NSNetServiceBrowser!
    var browsing = false
    var streamer: VgcStreamer!
    var serviceLookup = Dictionary<NSNetService, VgcService>()
    
    init(peripheral: Peripheral) {
        
        super.init()
        
        self.peripheral = peripheral
        
        elements = VgcManager.elements
        
        self.streamer = VgcStreamer(delegate: self, delegateName: "Browser")
        
        print("Setting up NSNetService for browsing")
        
        self.localService = NSNetService.init(domain: "local.", type: VgcManager.bonjourTypeCentral, name: deviceName, port: 0)
        self.localService.delegate = self
        self.localService.includesPeerToPeer = VgcManager.includesPeerToPeer
        
    }
    
    func closeStreams() {
        print("Closing streams")
        if inputStream != nil { inputStream.close() }
        if outputStream != nil { outputStream.close() }
    }
    
    // This is a callback from the streamer
    func disconnect() {
        print("Browser received disconnect")
        closeStreams()
        browsing = false
        peripheral.lostConnectionToCentral(connectedVgcService)
        connectedVgcService = nil
    }
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: AnyObject) {
        
        // Get the element in the message using the hash value reference
        guard let element = elements.elementFromIdentifier(elementIdentifier) else {
            print("ERROR: Received unknown element identifier: \(elementIdentifier) from \(connectedVgcService.fullName)")
            return
        }
        
        //print("Received net service message")
        
        var elementValueAsString: String = ""
        
        if element.dataType != .Data && element.dataType != .String { elementValueAsString = elementValue as! String }
        
        switch (element.type) {
            
        case .SystemMessage:
            
            let systemMessageType = SystemMessages(rawValue: Int(elementValueAsString)!)
            
            print("Central sent system message: \(systemMessageType!.description) to \(connectedVgcService.fullName)")
            
            NSNotificationCenter.defaultCenter().postNotificationName(VgcSystemMessageNotification, object: systemMessageType!.rawValue)
            
            break
            
        case .PeripheralSetup:
            
            element.valueAsBase64String = elementValueAsString
            
            NSKeyedUnarchiver.setClass(VgcPeripheralSetup.self, forClassName: "VgcPeripheralSetup")
            VgcManager.peripheralSetup = (NSKeyedUnarchiver.unarchiveObjectWithData(element.value as! NSData) as! VgcPeripheralSetup)

            print("Central sent peripheral setup: \(VgcManager.peripheralSetup)")

            NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralSetupNotification, object: nil)

            break
            
        case .PlayerIndex:
            
            let playerIndex = Int(elementValueAsString)
            if (playerIndex != nil) {
                //print ("Player index raw is \(playerIndex)")
                peripheral.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex!)!
                
                if deviceIsTypeOfBridge(){
                    
                    self.peripheral.controller.playerIndex = GCControllerPlayerIndex(rawValue: playerIndex!)!
                    
                }
                NSNotificationCenter.defaultCenter().postNotificationName(VgcNewPlayerIndexNotification, object: playerIndex)
            }
            
        default:
            
            switch (element.dataType) {
                
            case .Float:
                
                element.value = Float(elementValueAsString)!
                
            case .Data:
                
                element.value = elementValue
                
            case .String:
                
                element.value = NSString(data: elementValue as! NSData, encoding: NSUTF8StringEncoding) as! String
                
            default:
                
                element.value = elementValue
                
            }
            
            if !deviceIsTypeOfBridge() {
                
                // Call the handler set on the global object
                if let handler = element.valueChangedHandlerForPeripheral {
                    handler(element)
                }
            }
            
        }
        
        // If we're a bridge, send along the value to the Central
        if deviceIsTypeOfBridge() && element.type != .PlayerIndex {
            
            //peripheral.browser.sendElementStateOverNetService(element)
            peripheral.controller.sendElementStateToPeripheral(element)
            
        }
        
    }
    
    // Used by a Bridge to tell the Central that a Peripheral has disconnected.
    func disconnectFromCentral() {
        if connectedVgcService == nil { return }
        print("Browser sending system message Disconnect to \(connectedVgcService.fullName) from \(peripheral.controller.deviceInfo.vendorName)")
        elements.systemMessage.value = SystemMessages.Disconnect.rawValue
        sendElementStateOverNetService(elements.systemMessage)
        closeStreams()
    }
    
    // This is triggered by the Streamer if it receives a malformed message.  We just log it here.
    func sendInvalidMessageSystemMessage() {
        print("Peripheral received invalid checksum message from Central")
    }

    func sendElementStateOverNetService(let element: Element!) {
        
        if element == nil {
            print("Browser got attempt to send nil element to \(connectedVgcService.fullName)")
            return
        }
        
        var outputStream: NSOutputStream!
        
        if VgcManager.appRole == .Peripheral {
            outputStream = self.outputStream
        } else if deviceIsTypeOfBridge() {
            outputStream = peripheral.controller.toCentralOutputStream
        }
        
        /* This can cause a loop
        if (outputStream == nil || peripheral.haveConnectionToCentral == false) && (element.type != elements.systemMessage.type) {
            if deviceIsTypeOfBridge() { disconnectFromCentral() }
        }
*/
        
        if outputStream == nil {
            if connectedVgcService != nil { print("\(connectedVgcService.fullName) failed to send element \(element.name) because we don't have an output stream") } else { print("Failed to send element \(element.name) because we don't have an output stream") }
            return
        }
        
        if outputStream.hasSpaceAvailable == false {
            print("OutputStream has no space")
        }
        
        // Using a struct this way enables us to initalize our variables
        // only once
        struct PerformanceVars {
            static var messagesSent: Float = 0
            static var lastPublicationOfPerformance = NSDate()
        }
        
        if VgcManager.performanceSamplingEnabled {
            
            if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                let messagesPerSecond: Float = PerformanceVars.messagesSent / VgcManager.performanceSamplingDisplayFrequency
                print("\(messagesPerSecond) msgs/sec sent (Buffer has space: \(outputStream.hasSpaceAvailable))")
                PerformanceVars.messagesSent = 1
                PerformanceVars.lastPublicationOfPerformance = NSDate()
            }
        }

        if element.dataType == .Data || element.dataType == .String {
            
            streamer.streamNSDataForElement(element, stream: outputStream)
            
        } else {
            
            if streamer.largeDataTransferBusy == true {
                print("Ignoring small data because busy")
                //sendElementStateOverNetService(element)
            }
            
            let encodedDataArray = streamer.encodedMessageWithChecksum(element.identifier, value: element.value)
            outputStream.write(encodedDataArray, maxLength: encodedDataArray.count)
            
        }

        PerformanceVars.messagesSent = PerformanceVars.messagesSent + 1.0
        
    }

    func reset() {
        print("Resetting service browser")
        serviceLookup.removeAll()
    }
    
    func browseForCentral() {
        
        if browsing {
        
            print("Not browsing for central because already browsing")
            return
        
        }
        
        browsing = true
        
        print("Searching for Centrals on \(VgcManager.bonjourTypeCentral)")
        centralBrowser = NSNetServiceBrowser()
        centralBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
        centralBrowser.delegate = self
        centralBrowser.searchForServicesOfType(VgcManager.bonjourTypeCentral, inDomain: "local")
        
        // We only searches for bridges if we are not type bridge (bridges don't connect to bridges)
        if !deviceIsTypeOfBridge() {
            print("Searching for Bridges on \(VgcManager.bonjourTypeBridge)")
            bridgeBrowser = NSNetServiceBrowser()
            bridgeBrowser.includesPeerToPeer = VgcManager.includesPeerToPeer
            bridgeBrowser.delegate = self
            bridgeBrowser.searchForServicesOfType(VgcManager.bonjourTypeBridge, inDomain: "local")
        }
    }
    
    func stopBrowsing() {
        print("Stopping browse for Centrals")
        centralBrowser.stop()
        print("Stopping browse for Bridges")
        if !deviceIsTypeOfBridge() { bridgeBrowser.stop() } // Bridges don't browse for Bridges
        print("Clearing service lookup")
        browsing = false
        serviceLookup.removeAll()
    }
    
    func connectToService(vgcService: VgcService) {
        
        let service = vgcService.netService
        
        if (peripheral.haveConnectionToCentral == true) {
            print("Refusing to connect to service \(vgcService.fullName) because we already have a connection.")
            return
        }
        
        print("Attempting to connect to service: \(vgcService.fullName)")
        remoteServer = service
        var success: Bool
        var inStream: NSInputStream?
        var outStream: NSOutputStream?
        success = remoteServer.getInputStream(&inStream, outputStream: &outStream)
        if ( !success ) {
            print("Something went wrong connecting to service: \(vgcService.fullName)")
        } else {
            print("Successfully connected to service: \(vgcService.fullName)")
            
            connectedVgcService = vgcService
            
            if deviceIsTypeOfBridge() && peripheral.controller != nil {
                
                peripheral.controller.toCentralOutputStream = outStream;
                peripheral.controller.toCentralOutputStream.delegate = streamer
                peripheral.controller.toCentralOutputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                peripheral.controller.toCentralOutputStream.open()
                
                peripheral.controller.fromCentralInputStream = inStream
                peripheral.controller.fromCentralInputStream.delegate = streamer
                peripheral.controller.fromCentralInputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                peripheral.controller.fromCentralInputStream.open()
                
            } else {
                
                outputStream = outStream;
                outputStream.delegate = streamer
                outputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                outputStream.open()
                
                inputStream = inStream
                inputStream.delegate = streamer
                inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
                inputStream.open()
                
            }

            peripheral.gotConnectionToCentral()
        }
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        if (service == localService) {
            print("Ignoring service because it is our own: \(service.name)")
        } else {
            print("Found service of type \(service.type) at \(service.name)")
            var vgcService: VgcService
            if service.type == VgcManager.bonjourTypeBridge {
                vgcService = VgcService(name: service.name, type:.Bridge, netService: service)
            } else {
                vgcService = VgcService(name: service.name, type:.Central, netService: service)
            }
            
            serviceLookup[service] = vgcService
            
            NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralFoundService, object: vgcService)
            
            if deviceIsTypeOfBridge() && vgcService.type == .Central { connectToService(vgcService) }
        }
        
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        
        print("Service was removed: \(service.type) isMainThread: \(NSThread.isMainThread())")
        let vgcService = serviceLookup.removeValueForKey(service)
        print("VgcService was removed: \(vgcService?.fullName)")
        // If VgcService is nil, it means we already removed the service so we do not send the notification
        if vgcService != nil { NSNotificationCenter.defaultCenter().postNotificationName(VgcPeripheralLostService, object: vgcService) }
        
    }

    func netServiceBrowserDidStopSearch(browser: NSNetServiceBrowser) {
        browsing = false
    }
    
    func netServiceBrowser(browser: NSNetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print("Net service browser reports error \(errorDict)")
        browsing = false
    }
    
}
