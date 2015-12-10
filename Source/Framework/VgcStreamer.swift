//
//  VgcStreamer.swift
//  VirtualGameController
//
//  Created by Rob Reuss on 10/28/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation

@objc internal protocol VgcStreamerDelegate {
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: NSData)
    optional func disconnect()
    optional var deviceInfo: DeviceInfo! {get set}
    optional var centralPublisher: VgcCentralPublisher! {get set}
    optional func sendInvalidMessageSystemMessage()
    
}

class VgcStreamer: NSObject, NSNetServiceDelegate, NSStreamDelegate {

    private var elements: Elements!
    var delegate: VgcStreamerDelegate!
    var delegateName: String
    var malformedMessageCount: Int = 0
    var totalMessageCount: Int = 0
    var startTime: NSDate = NSDate()
    var dataBuffer: NSMutableData = NSMutableData()
    var expectedLength: Int = 0
    var elementIdentifier: Int!
    var transferType: TransferType = .Unknown
    var nsStringBuffer: NSString = ""
    var cycleCount: Int = 0
    let logging = false
    
    enum TransferType: Int, CustomStringConvertible {
        
        case Unknown
        case Ready
        case SmallData
        case LargeData
        
        var description : String {
            switch self {
            case .Unknown: return "Unknown"
            case .Ready: return "Ready"
            case .SmallData: return "SmallData"
            case .LargeData: return "LargeData"
            }
        }
    }
    
    init(delegate: VgcStreamerDelegate, delegateName: String) {
        
        self.delegate = delegate
        self.delegateName = delegateName
        elements = VgcManager.elements
        
    }
    
    deinit {
        print("Streamer deinitalized")
    }
    
    
    func writeElement(element: Element, toStream:NSOutputStream) {
        
        let messageData = element.dataMessage
        
        if logging { print("Sending Data for \(element.name):\(messageData.length) bytes") }
        
        writeData(messageData, toStream: toStream)
        
        if element.clearValueAfterTransfer {
            element.value = 0
        }
 
    }
    
    // Two indicators for handling a busy send queue, both of which result in the message being appended
    // to an NSMutableData var
    var dataSendQueue = NSMutableData()
    let lockQueueWriteData = dispatch_queue_create("net.simplyformed.lockQueueWriteData", nil)
    var streamerIsBusy: Bool = false
    var totalBusyTime: Float = 0.0
    
    func writeData(var data: NSData, toStream: NSOutputStream) {

        if VgcManager.appRole == .Peripheral && VgcManager.peripheral == nil {
            print("Attempt to write without peripheral object setup, exiting")
            return
        }
        
        // If no connection, clean-up queue and exit
        if VgcManager.appRole == .Peripheral && VgcManager.peripheral.haveOpenStreamsToCentral == false {
            print("No connection so clearing write queue")
            dataSendQueue = NSMutableData()
            return
        }

        if streamerIsBusy || !toStream.hasSpaceAvailable {
            print("OutputStream has no space/streamer is busy")
            if data.length > 0 {
                dispatch_sync(self.lockQueueWriteData) {
                    self.dataSendQueue.appendData(data)
                }
                print("Appended data queue, length: \(self.dataSendQueue.length)")
            }
            if self.dataSendQueue.length > 0 {
                
                // Avoid looping with lost connection
                totalBusyTime += 0.1
                if totalBusyTime > 2.0 {
                    print("Clearing data queue because of timeout")
                    totalBusyTime = 0
                    dataSendQueue = NSMutableData()
                    return
                }
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    
                    print("Recursively calling writeData to process queue")
                    // Send a trigger re-attempting the write request
                    self.writeData(NSData(), toStream: toStream)
                    
                }
            }
            return
       }

        if dataSendQueue.length > 0 {
            print("Processing data queue, length: \(dataSendQueue.length)")
            dataSendQueue.appendData(data)
            data = dataSendQueue
            dataSendQueue = NSMutableData()
        }

        streamerIsBusy = true

        var bytesWritten: NSInteger = 0
        while (data.length > bytesWritten) {
            
            let writeResult = toStream.write(UnsafePointer<UInt8>(data.bytes) + bytesWritten, maxLength: data.length - bytesWritten)
            if writeResult == -1 {
                print("ERROR: NSOutputStream returned -1")
                dispatch_sync(self.lockQueueWriteData) {
                    self.dataSendQueue = NSMutableData()
                }
                return
            } else {
                bytesWritten += writeResult
            }
            
        }
        
        if data.length != bytesWritten {
            print("ERROR: Got data transfer size mismatch")
        }
        
        streamerIsBusy = false
    }

    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        
        switch (eventCode){
 
        case NSStreamEvent.HasBytesAvailable:
            
            if logging { print("Stream status: \(aStream.streamStatus.rawValue)") }

            var bufferLoops = 0
            
            let headerLength = VgcManager.netServiceHeaderLength
            
            let inputStream = aStream as! NSInputStream
            
            var buffer = Array<UInt8>(count: VgcManager.netServiceBufferSize, repeatedValue: 0)
            
            while inputStream.hasBytesAvailable {
                
                bufferLoops++
               
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                if len <= 0 { return }
                
                if logging { print("Length of buffer: \(len)") }
                
                dataBuffer.appendData(NSData(bytes: &buffer, length: len))
                
            }
            
            if logging == true { print("Buffer size is \(dataBuffer.length) (Cycle count: \(cycleCount)) ((Buffer loops: \(bufferLoops))") }
            
            while dataBuffer.length > 0 {
                
                // This shouldn't happen
                if dataBuffer.length <= headerLength {
                    dataBuffer = NSMutableData()
                    print("ERROR: Streamer received data too short to have a header")
                    return
                }

                let headerIdentifier = dataBuffer.subdataWithRange(NSRange.init(location: 0, length: 4))
                if headerIdentifier == headerIdentifierAsNSData {
                    
                    var elementIdentifierUInt8: UInt8 = 0
                    let elementIdentifierNSData = dataBuffer.subdataWithRange(NSRange.init(location: 4, length: 1))
                    elementIdentifierNSData.getBytes(&elementIdentifierUInt8, length: sizeof(UInt8))
                    elementIdentifier = Int(elementIdentifierUInt8)
                    
                    var expectedLengthUInt32: UInt32 = 0
                    let valueLengthNSData = dataBuffer.subdataWithRange(NSRange.init(location: 5, length: 4))
                    valueLengthNSData.getBytes(&expectedLengthUInt32, length: sizeof(UInt32))
                    expectedLength = Int(expectedLengthUInt32)
                    
                } else {
                    
                    // This shouldn't happen
                    dataBuffer = NSMutableData()
                    print("ERROR: Streamer expected header but found no header identifier")
                    return
                }
                
                if expectedLength == 0 {
                    dataBuffer = NSMutableData()
                    print("ERROR: Streamer got expected length of zero")
                    return
                }

                var elementValueData = NSData()

                if dataBuffer.length < (expectedLength + headerLength) {
                    if logging { print("Streamer fetching additional data") }
                    break
                }

                elementValueData = dataBuffer.subdataWithRange(NSRange.init(location: headerLength, length: expectedLength))

                let dataRemainingAfterCurrentElement = dataBuffer.subdataWithRange(NSRange.init(location: headerLength + expectedLength, length: dataBuffer.length - expectedLength - headerLength))
                dataBuffer = NSMutableData(data: dataRemainingAfterCurrentElement)
                
                if elementValueData.length == expectedLength {
                    
                    //if logging { print("Got completed data transfer (\(elementValueData.length) of \(expectedLength))") }
                
                    let element = elements.elementFromIdentifier(elementIdentifier!)
                    
                    if element == nil {
                        print("ERROR: Unrecognized element")
                    } else {
                        
                        delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: elementValueData)
                        
                    }

                    elementIdentifier = nil
                    expectedLength = 0
                    
                    // Performance testing is about calculating elements received per second
                    // By sending motion data, it can be  compared to expected rates.
                    if VgcManager.performanceSamplingEnabled {
                        
                        struct PerformanceVars {
                            static var messagesSent: Float = 0
                            static var lastPublicationOfPerformance = NSDate()
                            static var invalidChecksums: Float = 0
                        }
                        
                        if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                            let messagesPerSecond: Float = PerformanceVars.messagesSent / VgcManager.performanceSamplingDisplayFrequency
                            print("\(messagesPerSecond) msgs/sec received")
                            PerformanceVars.messagesSent = 1
                            PerformanceVars.invalidChecksums = 0
                            PerformanceVars.lastPublicationOfPerformance = NSDate()
                        } else {
                            PerformanceVars.messagesSent = PerformanceVars.messagesSent + 1.0
                        }
                    }
                    
                    //if logging { print(" ") }
                    
                } else {
                    if logging { print("Streamer fetching additional data") }
                }

            }

            break
        case NSStreamEvent():
            NSLog("Streamer: All Zeros")
            break
            
        case NSStreamEvent.OpenCompleted:
            if aStream is NSInputStream {
                print("\(VgcManager.appRole) input stream is now open for \(delegateName)")
            } else {
                print("\(VgcManager.appRole) output stream is now open for \(delegateName)")
            }
            break
        case NSStreamEvent.HasSpaceAvailable:
            //print("HAS SPACE AVAILABLE")
            break
            
        case NSStreamEvent.ErrorOccurred:
            print("ERROR: Stream ErrorOccurred: Event Code: \(eventCode) (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            break
            
        case NSStreamEvent.EndEncountered:
            print("Streamer: EndEncountered (Delegate Name: \(delegateName))")
            delegate.disconnect!()
            
            break
            
        case NSStreamEvent.None:
            print("Streamer: Event None")
            break
        
            
        default:
            NSLog("default")
        }
    }
    
    func processDataMessage(dataMessage: NSString) {
        
        
        
    }
   
    func netService(sender: NSNetService, didUpdateTXTRecordData data: NSData) {
        print("CENTRAL: netService NetService didUpdateTXTRecordData")
    }
    
    func netServiceDidPublish(sender: NSNetService) {
        if deviceIsTypeOfBridge() {
            print("Bridge streamer is now published on: \(sender.domain + sender.type + sender.name)")
        } else {
            print("Central streamer is now published on: \(sender.domain + sender.type + sender.name)")
        }
    }
    
    func netService(sender: NSNetService, didNotPublish errorDict: [String : NSNumber]) {
        print("CENTRAL: Net service did not publish, error: \(errorDict)")
    }
    
    func netServiceWillPublish(sender: NSNetService) {
        print("NetService will be published")
    }
    
    func netServiceWillResolve(sender: NSNetService) {
        print("CENTRAL: netServiceWillResolve")
    }
    
    func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        print("CENTRAL: netService didNotResolve: \(errorDict)")
    }
    
    func netServiceDidResolveAddress(sender: NSNetService) {
        print("CENTRAL: netServiceDidResolveAddress")
    }
    
    func netServiceDidStop(sender: NSNetService) {
        print("CENTRAL: netServiceDidStop")
    }

    
    
}

