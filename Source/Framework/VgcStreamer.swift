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
    internal var largeDataTransferBusy: Bool = false
    
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
    
    func streamNSDataForElement(element: Element, stream: NSOutputStream) {
        
        largeDataTransferBusy = true
        
        var elementValueData: NSData!
        
        if element.dataType == .String {
            elementValueData = element.value.dataUsingEncoding(NSUTF8StringEncoding)! as NSData
        } else {
            elementValueData = element.value as! NSData
        }
        
        // DATA- 5 bytes
        // element identifier: 4 bytes
        // data length string: 13 bytes
        //
        // total message header length is 22
        // terminator is 9
        
        let elementIdentifierString = "\(element.identifier)".stringByPaddingToLength(3, withString: " ", startingAtIndex: 0)
        let lengthOfDataString = "\(elementValueData.length)".stringByPaddingToLength(13, withString: " ", startingAtIndex: 0)
        let messageHeaderString = "DATA-\(elementIdentifierString)-\(lengthOfDataString)"
        
        print("Header length: \(messageHeaderString.characters.count)")

        let messageHeaderData = messageHeaderString.dataUsingEncoding(NSUTF8StringEncoding)
        
        //let messageHeaderData = "DATA".dataUsingEncoding(NSUTF8StringEncoding)
        print("Message header data: \(messageHeaderData)")
        
        print("Message Header data length \(messageHeaderData!.length), message header string length \(messageHeaderString.characters.count), element value length: \(elementValueData.length), header string: \(messageHeaderString)")

        let completeData = NSMutableData()
        completeData.appendData(messageHeaderData!)
        completeData.appendData(elementValueData)
        var bytesWritten: NSInteger = 0
        
        print("Sending Data for \(element.name):\(completeData.length) bytes")
        
        while (completeData.length > bytesWritten) {
            
            let write = stream.write(UnsafePointer<UInt8>(completeData.bytes) + bytesWritten, maxLength: completeData.length - bytesWritten)
            if write == -1 {
                print("    Error sending data for: \(element.name)")
                largeDataTransferBusy = false
                return
            } else {
                bytesWritten += write
                //print("    Sent \(bytesWritten) bytes")
            }
            
            // If we've sent all the bytes, send terminator
            if bytesWritten == completeData.length {
                // Need a slight delay here or the message will not properly send on faster hardware
                let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(0.1 * Double(NSEC_PER_SEC)))
                dispatch_after(delayTime, dispatch_get_main_queue()) {
                    //print("    Sending termination message (Bytes written: \(bytesWritten))")
                    //let encodedArray = self.encodedMessageWithChecksum(element.identifier, value: VgcManager.netServiceDataTerminator)
                    //stream.write(encodedArray, maxLength: encodedArray.count)

                }

            }
        }
        
        if completeData.length > bytesWritten {
            print("Got data transfer mismatch")
        }
        
        largeDataTransferBusy = false
    }
    
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        
        switch (eventCode){

        case NSStreamEvent.HasBytesAvailable:
            
            //print("Operating on thread: \(NSThread.currentThread()) (\(transferType))")
            
            if transferType == .Unknown { transferType = .Ready }
            
            let inputStream = aStream as! NSInputStream
            
            var buffer = Array<UInt8>(count: VgcManager.netServiceBufferSize, repeatedValue: 0)
            
            var nsStringBuffer: NSString = ""
            
            var cycleCount = 1
            
            // Loop through and get a complete message in case the message is passed
            // in fragments - we look for a terminating newline
            while inputStream.hasBytesAvailable {
                
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                let testData = NSData(bytes: &buffer, length: len)
                var messageHeaderString: NSString = ""
                
                //print("Evaluating incoming data for small or large (\(transferType))")
                
                if len > 0 {
                    
                    // Test for large data transfer by checking header
                    if transferType == .Ready {

                        if testData.length >= 22 {
                            let messageHeaderData = testData.subdataWithRange(NSRange.init(location: 0, length: 22))
                            let dataFlag = messageHeaderData.subdataWithRange(NSRange.init(location: 0, length: 4))
                            let dataFlagExpected = "DATA".dataUsingEncoding(NSUTF8StringEncoding)
                            if dataFlag == dataFlagExpected {
                            
                                print("Message header data: \(messageHeaderData) (\(transferType))")
                                messageHeaderString = NSString(data: messageHeaderData, encoding: NSUTF8StringEncoding)!
                                let messageHeaderComponents = messageHeaderString.componentsSeparatedByString("-")
                                if messageHeaderComponents.count == 3 {
                                    
                                    if messageHeaderComponents[0] == "DATA" {
                                        
                                        print("Confirmed large data incoming")
                                        
                                        transferType = .LargeData
                                        
                                        let elementIdentifierNSString = (messageHeaderComponents[1] as NSString)
                                        elementIdentifier = Int(elementIdentifierNSString.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, elementIdentifierNSString.length)))
                                        
                                        print("Large transfer element identifier: \(elementIdentifier) (\(transferType))")
                                        
                                        let dataMessageExpectedLengthNSString = (messageHeaderComponents[2] as NSString)
                                        let dataMessageExpectedLengthString = dataMessageExpectedLengthNSString.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, dataMessageExpectedLengthNSString.length))
                                        
                                        dataMessageExpectedLength = Int(dataMessageExpectedLengthString)!
                                        
                                        print("Large transfer expected data length: \(dataMessageExpectedLength) (\(transferType))")
                                        
                                    }
                                }
                            }
                        }
                    }
                    
                    if transferType == .Ready {
                        
                        transferType = .SmallData
                        //print("Confirmed small data incoming (\(transferType))")

                        if var rawContentsNSString = NSString(bytes: &buffer, length: len, encoding: NSUTF8StringEncoding) {
                            rawContentsNSString = rawContentsNSString.stringByReplacingOccurrencesOfString("\0", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, rawContentsNSString.length))
                            
                            nsStringBuffer = "\(nsStringBuffer)\(rawContentsNSString)" as NSString
                            
                            cycleCount++
                        }
                        
                    } else if transferType == .LargeData {
                    
                        //print("Message header: \(messageHeaderString), dataBuffer: \(dataBuffer.length), Working on data: \(workingOnBigData), Test Data Length: \(testData.length), Expected Length: \(dataMessageExpectedLength)")
                        
                        //print("Processing large data (\(dataBuffer.length) of \(dataMessageExpectedLength)) (\(transferType))")
                        
                       var messageData = NSData()
                        
                        // Test if we're processing the initial set of data that includes the header
                        if messageHeaderString != "" {
                            let messageDataLength = len - 22
                            messageData = testData.subdataWithRange(NSRange.init(location: 22, length: messageDataLength))
                        } else {
                            messageData = testData
                        }
                        
                        // Test to see if we've received some "small" data during a large data transfer
                        let remainingBytesToTransfer = dataMessageExpectedLength - dataBuffer.length
                        if testData.length > VgcManager.netServiceBufferSize && remainingBytesToTransfer > VgcManager.netServiceBufferSize {
                            print("ERROR: Transfer size is too large for large data transfer")
                            return
                        }
                        
                        // Response is in the form of data bytes
                        //let data = NSData(bytes: &buffer, length: len)
                        dataBuffer.appendData(messageData)

                        if dataBuffer.length >= dataMessageExpectedLength {
                            
                            print("Got completed big data transfer (\(dataBuffer.length) of \(dataMessageExpectedLength)) (\(transferType))")
                            
                            if dataBuffer.length > dataMessageExpectedLength {
                                print("ERROR: Recieved more bytes than expected (by \(dataBuffer.length - dataMessageExpectedLength)")
                                print("")
                            }
                            
                            let element = elements.elementFromIdentifier(elementIdentifier!)
                            
                            //print("Got element: \(element)")
                            
                            if element.dataType == .String {
                                
                                let valueString = NSString(data: dataBuffer, encoding: NSUTF8StringEncoding) // NSUTF8StringEncoding
                                delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: valueString!)
                                
                            } else {
                                
                                delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: dataBuffer)
                                
                            }
                            
                            dataBuffer = NSMutableData()
                            transferType = .Ready
                            elementIdentifier = nil
                            dataMessageExpectedLength = 0
                            
                            return
                    }

                    }

                } else {
                    print("Received empty stream")
                    return
                }
            }
            
            if transferType == .LargeData {
                //print("Returning for more large data (\(transferType))")
                return
            }
            
            //print("Running main small data processing (\(transferType))")
            
            transferType = .Ready // Reset this for when we're done processing small data below
            
            cycleCount = 1
            
            // Do we have a message or messages?
            if nsStringBuffer.length > 0 {
                
                var messageToProcess = nsStringBuffer as String
                
                //nsStringBuffer = ""
                
                //messageToProcess = messageToProcess.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet())
                messageToProcess = messageToProcess.stringByReplacingOccurrencesOfString("\0", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
                
                // If there is a message separator at the beginning, remove it because it will
                // cause componentsSeparatedByString to return nil
                if messageToProcess.characters.first! == "\n" {
                    messageToProcess = String(messageToProcess.characters.dropFirst())
                }
                
                if messageToProcess == "" { break }
                
                // Same thing - we don't want a message seperator at the end
                guard let lastCharacter = messageToProcess.characters.last else { break }
                if lastCharacter == "\n" {
                    messageToProcess = String(messageToProcess.characters.dropLast())  // Must not have trailing /n or array will have no members
                }
                
                // Create an array of indvidiual messages
                var messages = messageToProcess.componentsSeparatedByString("\n")
                
                totalMessageCount++
                
                // If we don't get any members in the array, it means a single value
                // has come through, so add that to the array
                if messages.count == 0 && messageToProcess.characters.count > 0 {
                    print("Found single value")
                    messages.append(messageToProcess)
                }
                
                // Iterate through the messages in the array
                while messages.count > 0 {
                    
                    // Grab the most recent message off the array for processing
                    let message = messages.removeFirst()
                    
                    // Split the message between the element reference and the element value
                    let messageParts = message.componentsSeparatedByString(messageValueSeperator)
                    if messageParts.count != 3 {
                        //print("Incomplete message: \(message)")
                        return
                    }
                    let checksum = (messageParts.first! as NSString).floatValue
                    let elementID = messageParts[1]
                    let elementValue = messageParts.last!
                    let elementIdentifier = Int(elementID)
                    
                    let messageString = "\(elementID)\(messageValueSeperator)\(elementValue)"
                    let stringLength = messageString.characters.count
                    
                    let element = elements.elementFromIdentifier(elementIdentifier!)
                    
                    var expectedChecksum: Float
                    
                    if element.dataType == .String || element.dataType == .Data {
                        print(stringLength)
                        expectedChecksum = Float(stringLength)

                    } else {
                        expectedChecksum = (elementValue as NSString).floatValue + Float(elementIdentifier!) + Float(stringLength)
                    }
                    
                    // Performance testing is about calculating elements received per second
                    // By sending motion data, it can be easily compared to expected rates.
                    if VgcManager.performanceSamplingEnabled {
                        
                        struct PerformanceVars {
                            static var messagesSent: Float = 0
                            static var lastPublicationOfPerformance = NSDate()
                            static var invalidChecksums: Float = 0
                        }
                        
                        if "\(checksum)" != "\(expectedChecksum)" {
                            //print("ERROR: Invalid checksum: \(expectedChecksum) v. \(checksum) with msg [\(message)] (\(delegate.deviceInfo.vendorName))")
                            PerformanceVars.invalidChecksums++
                            delegate.sendInvalidMessageSystemMessage!()
                        }
                        
                        if Float(PerformanceVars.lastPublicationOfPerformance.timeIntervalSinceNow) < -(VgcManager.performanceSamplingDisplayFrequency) {
                            let messagesPerSecond: Float = PerformanceVars.messagesSent / VgcManager.performanceSamplingDisplayFrequency
                            let invalidChecksumsPerMinute: Float = (PerformanceVars.invalidChecksums / VgcManager.performanceSamplingDisplayFrequency)
                            print("\(messagesPerSecond) msgs/sec received | \(invalidChecksumsPerMinute) invalid checksums/sec")
                            PerformanceVars.messagesSent = 1
                            PerformanceVars.invalidChecksums = 0
                            PerformanceVars.lastPublicationOfPerformance = NSDate()
                        } else {
                            PerformanceVars.messagesSent = PerformanceVars.messagesSent + 1.0
                        }
                    }
                    
                    if "\(checksum)" != "\(expectedChecksum)" { continue }
                    
                    // If we have a well-formed message, continue
                    if elementIdentifier != nil && messageParts.count == 3 {
                        
                        delegate.receivedNetServiceMessage(elementIdentifier!, elementValue: elementValue)
                        
                        
                    } else { // Malformed because it did not result in two components or was nil
                        
                        //print("ERROR: Got malformed message (\(delegate.deviceInfo.vendorName): [\(messageToProcess)] [\(message)]")
                        malformedMessageCount++
                        
                        // Failure rate calculation
                        let percentageMalformedMessages = Float(malformedMessageCount / totalMessageCount)
                        let elapsedTimeInSeconds = fabs(startTime.timeIntervalSinceNow)
                        print("Elapsed time in seconds: \(elapsedTimeInSeconds)")
                        let elapsedTimeInMinutes = elapsedTimeInSeconds / 60
                        print("Elapsed time in minutes: \(elapsedTimeInMinutes)")
                        let malformedPerMinute =  Double(malformedMessageCount) / elapsedTimeInMinutes
                        let messagesPerMinute = Double(totalMessageCount) / elapsedTimeInMinutes
                        print("Msgs: \(totalMessageCount), Msgs/Min: \(messagesPerMinute), Malformed: \(malformedMessageCount), \(percentageMalformedMessages)%, Per/minute: \(malformedPerMinute)")
                    }
                    
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
    
    func encodedMessageWithChecksum(identifier: Int, value: AnyObject) -> [UInt8] {
        
        let stringLength = "\(identifier)\(messageValueSeperator)\(value)".characters.count
        let element = VgcManager.elements.elementFromIdentifier(identifier)
        if element.dataType != .Data && element.dataType != .String  {
            let checksum = value as! Float + Float(identifier) + Float(stringLength)
            return [UInt8]("\(checksum)\(messageValueSeperator)\(identifier)\(messageValueSeperator)\(value)\n".utf8)
        } else {
            let checksum = stringLength // trim the terminating three equal signs from the count
            return [UInt8]("\(checksum)\(messageValueSeperator)\(identifier)\(messageValueSeperator)\(value)\n".utf8)
        }
        
    }
    
    
}

