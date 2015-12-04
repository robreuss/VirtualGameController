//
//  VgcStreamer.swift
//  VirtualGameController
//
//  Created by Rob Reuss on 10/28/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation

@objc internal protocol VgcStreamerDelegate {
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: AnyObject)
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
    var dataMessageExpectedLength: Int = 0
    var elementIdentifier: Int!
    var transferType: TransferType = .Unknown
    var nsStringBuffer: NSString = ""
    var cycleCount: Int = 0
    
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
    
    func writeElementAsNSData(element: Element, toStream:NSOutputStream) {
        
        var elementValueData: NSData!
        
        if element.dataType == .String {
            elementValueData = element.value.dataUsingEncoding(NSUTF8StringEncoding)! as NSData
        } else if element.dataType == .Float {
            elementValueData = "\(element.value)".dataUsingEncoding(NSUTF8StringEncoding)! as NSData
        } else if element.dataType == .Data  {
            elementValueData = element.value as! NSData
        } else {
            print("Data type unsupported by writeElementAsNSData: \(element.dataType)")
            return
        }
        
        let elementIdentifierString = "\(element.identifier)".stringByPaddingToLength(3, withString: " ", startingAtIndex: 0)
        let lengthOfDataString = "\(elementValueData.length)".stringByPaddingToLength(13, withString: " ", startingAtIndex: 0)
        let messageHeaderString = "DATA-\(elementIdentifierString)-\(lengthOfDataString)"
        
        print("Header length: \(messageHeaderString.characters.count)")

        let messageHeaderData = messageHeaderString.dataUsingEncoding(NSUTF8StringEncoding)
       
        //let messageHeaderData = "DATA".dataUsingEncoding(NSUTF8StringEncoding)
        print("Message header data: \(messageHeaderData)")
        
        print("Message Header data length \(messageHeaderData!.length), message header string length \(messageHeaderString.characters.count), element value length: \(elementValueData.length), header string: \(messageHeaderString)")

        let messageData = NSMutableData()
        messageData.appendData(messageHeaderData!)
        messageData.appendData(elementValueData)
        
        print("Sending Data for \(element.name):\(messageData.length) bytes")
        
        writeData(messageData, toStream: toStream)
 
    }
    
    func writeElement(element: Element, toStream: NSOutputStream) {
        
        writeElementAsNSData(element, toStream: toStream)
        
    }
    
    /*
    func writeElement(element: Element, toStream: NSOutputStream) {
        
        var stringToSend: String
        let stringLength = "\(element.identifier)\(messageValueSeperator)\(element.value)".characters.count
        if element.dataType != .Data && element.dataType != .String  {
            let checksum: Float = element.value as! Float + Float(element.identifier) + Float(stringLength)
            stringToSend = "\(checksum)\(messageValueSeperator)\(element.identifier)\(messageValueSeperator)\(element.value)\n"
        } else {
            stringToSend = "\(stringLength)\(messageValueSeperator)\(element.identifier)\(messageValueSeperator)\(element.value)\n"
        }
        let messageData = stringToSend.dataUsingEncoding(NSUTF8StringEncoding)
        if !toStream.hasSpaceAvailable {
            print("No space: \(element.name)")
        }
        writeData(messageData!, toStream: toStream)
    }
    */
    
    var dataSendQueue = NSMutableData()
    let lockQueueWriteData = dispatch_queue_create("net.simplyformed.lockQueueWriteData", nil)
    var streamerIsBusy: Bool = false
    
    func writeData(var data: NSData, toStream: NSOutputStream) {

        if data.length == 0 { return }

        if (streamerIsBusy || !toStream.hasSpaceAvailable) {
            print("Output stream has space available: \(toStream.hasSpaceAvailable)")
            print("OutputStream has no space/streamer is busy: \(NSString(data: data, encoding: NSUTF8StringEncoding))")
            dispatch_sync(self.lockQueueWriteData) {
                self.dataSendQueue.appendData(data)
            }
            print("Appended dataSendQueue, length: \(self.dataSendQueue.length)")
            let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
            dispatch_after(delayTime, dispatch_get_main_queue()) {
                self.writeData(NSData(), toStream: toStream)
            }
       }

        if dataSendQueue.length > 0 {
            print("Processing dataSendQueue, length: \(dataSendQueue.length)")
            dataSendQueue.appendData(data)
            data = dataSendQueue
            dataSendQueue = NSMutableData()
        }

        streamerIsBusy = true

        var bytesWritten: NSInteger = 0
        while (data.length > bytesWritten) {
            
            let writeResult = toStream.write(UnsafePointer<UInt8>(data.bytes) + bytesWritten, maxLength: data.length - bytesWritten)
            if writeResult == -1 {
                print("    Error sending data")
                return
            } else {
                bytesWritten += writeResult
                //print("    Sent \(bytesWritten) bytes")
            }
            
        }
        if data.length != bytesWritten {
            print("Got data transfer size mismatch")
        }
        streamerIsBusy = false
    }

    let dataFlagExpected = "DATA".dataUsingEncoding(NSUTF8StringEncoding)
    var foundMessageHeader = false
    
    let logging = true
    
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        
        switch (eventCode){
 
        case NSStreamEvent.HasBytesAvailable:
            
            //print("Stream status: \(aStream.streamStatus.rawValue)")
            
            //print("Operating on thread: \(NSThread.currentThread()) (\(transferType))")

            var bufferLoops = 0
            
            let headerLength = VgcManager.netServiceHeaderLength
            
            let inputStream = aStream as! NSInputStream
            
            var buffer = Array<UInt8>(count: VgcManager.netServiceBufferSize, repeatedValue: 0)
            
            var messageHeaderString: NSString
            
            while inputStream.hasBytesAvailable {
                
                bufferLoops++
               
                let len = inputStream.read(&buffer, maxLength: buffer.count)

                messageHeaderString = ""
                
                dataBuffer.appendData(NSData(bytes: &buffer, length: len))
                
            }
            
            if logging == true { print("Buffer size is \(dataBuffer.length) (Cycle count: \(cycleCount)) ((Buffer loops: \(bufferLoops))") }
            
            //print("Evaluating incoming data for small or large (\(transferType))")
            
            while dataBuffer.length > 0 {
                
                if dataBuffer.length <= headerLength { return }

                let dataFlag = dataBuffer.subdataWithRange(NSRange.init(location: 0, length: 4))
                if dataFlag == dataFlagExpected {
                    let messageHeaderData = dataBuffer.subdataWithRange(NSRange.init(location: 0, length: headerLength))
                    messageHeaderString = NSString(data: messageHeaderData, encoding: NSUTF8StringEncoding)!
                    if logging { print("Message header string: [\(messageHeaderString)]") }
                    let messageHeaderComponents = messageHeaderString.componentsSeparatedByString("-")
                    if messageHeaderComponents.count == 3 {
                        
                        if messageHeaderComponents[0] == "DATA" {
                            
                            let elementIdentifierNSString = (messageHeaderComponents[1] as NSString)
                            elementIdentifier = Int(elementIdentifierNSString.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, elementIdentifierNSString.length)))
                            
                            let dataMessageExpectedLengthNSString = (messageHeaderComponents[2] as NSString)
                            let dataMessageExpectedLengthString = dataMessageExpectedLengthNSString.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, dataMessageExpectedLengthNSString.length))
                            dataMessageExpectedLength = Int(dataMessageExpectedLengthString)!
                            if logging { print("Header says identity: \(elementIdentifier) Length: \(dataMessageExpectedLength)") }
                            
                            foundMessageHeader = true

                        }
                    } else {
                        print("Unable to componentize large data header")
                        return
                    }
                }
                
                var individualMessageData = NSData()

                if dataBuffer.length < (dataMessageExpectedLength + 22) {
                    if logging { print("Incomplete message, getting more data \(dataBuffer.length)") }
                    if logging { print("Data buffer: [\(NSString(data: dataBuffer, encoding: NSUTF8StringEncoding))]") }
                    if logging { print("BREAKING, REQUIRE ANOTHER PASS") }
                    break
                } else {
                    if logging { print("Data buffer: [\(NSString(data: dataBuffer, encoding: NSUTF8StringEncoding))]") }
                }

                if logging { print("Data buffer length: \(dataBuffer.length)") }
                individualMessageData = dataBuffer.subdataWithRange(NSRange.init(location: headerLength, length: dataMessageExpectedLength))
                if logging { print("Message data: [\(NSString(data: individualMessageData, encoding: NSUTF8StringEncoding))]") }

                if dataMessageExpectedLength == 0 {
                    print("No header")
                }

                let remainingData = dataBuffer.subdataWithRange(NSRange.init(location: headerLength + dataMessageExpectedLength, length: dataBuffer.length - dataMessageExpectedLength - headerLength))
                dataBuffer = NSMutableData(data: remainingData)
                
                if individualMessageData.length == dataMessageExpectedLength {
                    
                    if logging { print("Got completed data transfer (\(individualMessageData.length) of \(dataMessageExpectedLength))") }
                
                    let element = elements.elementFromIdentifier(elementIdentifier!)
                    
                    if element == nil {
                        print("ERROR: Unrecognized element")
                    } else {

                         if element.dataType == .String || element.dataType == .Float {
                        
                            let valueString = NSString(data: individualMessageData, encoding: NSUTF8StringEncoding) // NSUTF8StringEncoding
                            delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: valueString!)
                            
                            if logging { print("Float value is \(valueString!)") }
                            
                        } else {

                            delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: individualMessageData)
                            
                        }
                    }

                    elementIdentifier = nil
                    dataMessageExpectedLength = 0
                    messageHeaderString = ""
                    foundMessageHeader = false
                    
                    if logging { print(" ") }
                    
                } else {
                    if logging { print("RETURNING, REQUIRE ANOTHER PASS") }
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
            print("HAS SPACE AVAILABLE")
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

