//
//  VgcStreamer.swift
//  VirtualGameController
//
//  Created by Rob Reuss on 10/28/15.
//  Copyright © 2015 Rob Reuss. All rights reserved.
//

import Foundation

@objc internal protocol VgcStreamerDelegate {
    
    func receivedNetServiceMessage(elementIdentifier: Int, elementValue: String)
    optional func disconnect()
    optional var deviceInfo: DeviceInfo! {get set}
    optional var centralPublisher: VgcCentralPublisher! {get set}
    optional func receivedInvalidMessage()
    
}

class VgcStreamer: NSObject, NSNetServiceDelegate, NSStreamDelegate {
    
    var delegate: VgcStreamerDelegate!
    var delegateName: String
    var malformedMessageCount: Int = 0
    var totalMessageCount: Int = 0
    var startTime: NSDate = NSDate()
    
    init(delegate: VgcStreamerDelegate, delegateName: String) {
        
        self.delegate = delegate
        self.delegateName = delegateName
        
    }
    
    deinit {
        print("Streamer deinitalized")
    }
    
    func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        
        switch (eventCode){
            
            // Process messages from the inputStream
        case NSStreamEvent.HasBytesAvailable:
            
            let inputStream = aStream as! NSInputStream
            
            //let lockQueue = dispatch_queue_create("net.simplyformed.BufferLockQueue", nil)
            
            var buffer = Array<UInt8>(count: VgcManager.netServiceBufferSize, repeatedValue: 0)
            
            var nsStringBuffer: NSString = ""
            
            var cycleCount = 1
            
            // Loop through and get a complete message in case the message is passed
            // in fragments - we look for a terminating newline
            while inputStream.hasBytesAvailable {
                
                let len = inputStream.read(&buffer, maxLength: buffer.count)
                
                if len > 0 {
                    
                    if var rawContentsNSString = NSString(bytes: &buffer, length: len, encoding: NSUTF8StringEncoding) {
                        rawContentsNSString = rawContentsNSString.stringByReplacingOccurrencesOfString("\0", withString: "", options: NSStringCompareOptions.LiteralSearch, range: NSMakeRange(0, rawContentsNSString.length))
                        
                        nsStringBuffer = "\(nsStringBuffer)\(rawContentsNSString)" as NSString
                        
                        cycleCount++
                    }
                    
                } else {
                    print("Received empty stream")
                    return
                }
            }
            
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
                    
                    let expectedChecksum = (elementValue as NSString).floatValue + Float(elementIdentifier!) + Float(stringLength)
                    
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
                            delegate.receivedInvalidMessage!()
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
        var checksum: Float
        if identifier != elements.deviceInfoElement.identifier && !(value is String)  {
            checksum = value as! Float + Float(identifier) + Float(stringLength)
        } else {
            checksum = Float(identifier) + Float(stringLength)
        }
        return [UInt8]("\(checksum)\(messageValueSeperator)\(identifier)\(messageValueSeperator)\(value)\n".utf8)
        
    }
    
    
}

