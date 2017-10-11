//
//  VgcWebSockets.swift
//
//
//  Created by Rob Reuss on 10/10/17.
//

#if !os(watchOS)

import Foundation
import Starscream

/*
struct Command: Codable {
    enum Commands: String, Codable {
        case publishCentral, unpublishCentral, connectPeripheral, getCentralList
    }
    var command: Commands
}

struct CentralID: Codable {
    var centralID: String
}
 //let command = Command(command: .publishCentral)
 //let centralID = CentralID(centralID: "mycentralid")
 
*/
    
    struct Service: Codable {
        enum Commands: String, Codable {
            case addedService, removedService
        }
        var command: Commands
        var name: String!
        var ID: String!
    }

class WebSocketCentral: WebSocketDelegate {
    
    var socket: WebSocket!
    var controller: VgcController!
    
    func publishCentral(ID: String)  {
        
        print("websocket attempting to connect to server")
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/central")!)
        socket.delegate = self
        socket.onConnect = {
            print("websocket is connected")
            
            let commandDictionary = ["command": "publishCentral", "centralID": ID]
            let jsonEncoder = JSONEncoder()
            do {
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                //let jsonDataCommand = try jsonEncoder.encode(command)
                print("JSON String : " + jsonString!)
                self.socket.write(string: jsonString!)
            }
            catch {
            }
 
        }
        socket.connect()
    }
    
    func websocketDidConnect(socket: WebSocketClient) {

    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        do {
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            print("Peripheral received message: \(rawJSON)")
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "peripheralConnected":
                    print("Peripheral connected, JSON: \(rawJSON), creating controller")
                    
                    controller = VgcController()
                    let deviceInfo = DeviceInfo(deviceUID: "jfjf", vendorName: "dddd", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
                    controller.deviceInfo = deviceInfo
                    
                default:
                    print("Default")
                }
            }
            
        } catch {
            
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("central got some data: \(data.count)")
        
        var dataBuffer = NSMutableData(data: data)
        let headerLength = VgcManager.netServiceHeaderLength
        var elementIdentifer: Int
        var expectedLength: Int
        let headerIdentifier = dataBuffer.subdata(with: NSRange.init(location: 0, length: 4))
        if headerIdentifier == headerIdentifierAsNSData as Data {
            
            var elementIdentifierUInt8: UInt8 = 0
            let elementIdentifierNSData = dataBuffer.subdata(with: NSRange.init(location: 4, length: 1))
            (elementIdentifierNSData as NSData).getBytes(&elementIdentifierUInt8, length: MemoryLayout<UInt8>.size)
            elementIdentifer = Int(elementIdentifierUInt8)
            
            var expectedLengthUInt32: UInt32 = 0
            let valueLengthNSData = dataBuffer.subdata(with: NSRange.init(location: 5, length: 4))
            (valueLengthNSData as NSData).getBytes(&expectedLengthUInt32, length: MemoryLayout<UInt32>.size)
            expectedLength = Int(expectedLengthUInt32)
            
            let elementValueData = dataBuffer.subdata(with: NSRange.init(location: headerLength, length: expectedLength))
            
            let element = VgcManager.elements.elementFromIdentifier(elementIdentifer)
  
            controller.receivedNetServiceMessage(elementIdentifer, elementValue: elementValueData)
        }

    }
    
}

class WebSocketPeripheral: WebSocketDelegate {
    
    var socket: WebSocket!
    
    func getCentralList()  {
        
        print("websocket attempting to connect to server")
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/peripheral")!)
        socket.delegate = self
        socket.onConnect = {
            let commandDictionary = ["command": "getServiceList"]
            let jsonEncoder = JSONEncoder()
            do {
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                print("JSON String : " + jsonString!)
                self.socket.write(string: jsonString!)
            }
            catch {
            }
            
        }
        socket.connect()
        
    }
    
    func sendElement(element: Element) {
  
        print("Sending element data message")
        self.socket.write(data: element.dataMessage as Data)
        
    }
    
    func websocketDidConnect(socket: WebSocketClient) {

    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {

        do {
            
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "addedService":
                    print("Received addedService, JSON: \(rawJSON)")
                    
                    let service = try! JSONDecoder().decode(Service.self, from: text.data(using: .utf8)!)
                    
                    let commandDictionary = ["command": "connectPeripheral", "peripheralID": "1", "centralID": service.ID]
                    let jsonEncoder = JSONEncoder()
                    do {
                        let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                        let jsonString = String(data: jsonDataDict, encoding: .utf8)
                        print("JSON String : " + jsonString!)
                        self.socket.write(string: jsonString!)
                    }
                    catch {
                    }
                    VgcManager.peripheral.haveConnectionToCentral = true
                    NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)

                    //print("App role: \(VgcManager.appRole)")
                    //let netService = NetService()
                    //var vgcService = VgcService(name: service.name, type:.Central, netService: netService)
                    //VgcManager.peripheral.browser.serviceLookup[netService] = vgcService
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralFoundService), object: vgcService)
                    
                default:
                    print("Default")
                }
            }
            
        } catch {
            
        }
        

    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("peripheral got some data: \(data.count)")
    }
    
}

#endif
