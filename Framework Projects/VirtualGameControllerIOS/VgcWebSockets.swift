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
        
        vgcLogDebug("Central connecting to server")
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/central")!)
        socket.delegate = self
        socket.onConnect = {
            
            vgcLogDebug("Central has a connected socket")
            
            let commandDictionary = ["command": "publishCentral", "centralID": ID]
            let jsonEncoder = JSONEncoder()
            do {
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                vgcLogDebug("Central publishing to server")
                self.socket.write(string: jsonString!)
            }
            catch {
            }
 
        }
        socket.connect()
    }
    
    func sendElement(element: Element) {
        
        if let _ = self.socket {
            //print("Sending element data message")
            self.socket.write(data: element.dataMessage as Data)
            //print("Finished sending")
        } else {
            vgcLogError("Got nil socket")
        }
        
    }
    
    func websocketDidConnect(socket: WebSocketClient) {

    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("websocket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        do {
            
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            vgcLogDebug("Central received text message: \(text)")
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "peripheralConnected":
                    
                    vgcLogDebug("A peripheral has connected to the central via the server")
                    
                    if let peripheralID = rawJSON["peripheralID"] {
                        vgcLogDebug("Creating a peripheral controller on the central with peripheralID \(peripheralID)")
                        controller = VgcController()
                        controller.webSocket = self
                        controller.sendConnectionAcknowledgement()
                        
                        // Publish another service for the next controller
                        VgcController.centralPublisher.publishService()
                        
                        //let deviceInfo = DeviceInfo(deviceUID: peripheralID, vendorName: "dddd", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
                        //controller.deviceInfo = peripheral.dev
                    }
                    
                default:
                    print("Default")
                }
            }
            
        } catch {
            
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        //print("central got some data: \(data.count)")
        
        let mutableData = NSMutableData(data: data)
        
        let (element, remainingData) = VgcManager.elements.processMessage(data: mutableData)
        
        if let elementUnwrapped = element {
            if elementUnwrapped.type == .deviceInfoElement {
                print("Got device info")
                controller.updateGameControllerWithValue(elementUnwrapped)
            } else {
               controller.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
            }
        } else {
            vgcLogError("Central got non-element from processMessage")
        }

    }
    
}

class WebSocketPeripheral: WebSocketDelegate {
    
    var socket: WebSocket!
    var streamDataType: StreamDataType = .largeData
    
    func setup() {
        
        vgcLogDebug("Setting-up socket-based peripheral")
        
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/peripheral")!)
        socket.delegate = self
        
        socket.onConnect = {
            let commandDictionary = ["command": "getServiceList"]
            let jsonEncoder = JSONEncoder()
            do {
                vgcLogDebug("Peripheral requesting service list from server")
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                self.socket.write(string: jsonString!)
            }
            catch {
            }
            
        }
    }
    
    func getCentralList()  {
        
        vgcLogDebug("Peripheral attempting to connect to server")
        socket.connect()
        
    }
    
    func sendElement(element: Element) {
  
        if let _ = self.socket {
            //print("Sending element data message")
            self.socket.write(data: element.dataMessage as Data)
            //print("Finished sending")
        } else {
            vgcLogError("Got nil socket")
        }
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        vgcLogDebug("Peripheral connected to server and has a socket")
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        vgcLogDebug("Peripheral socket is disconnected: \(error?.localizedDescription)")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {

        do {
            
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "addedService":
                    
                    vgcLogDebug("Peripheral notification that a service has been added")
                    
                    let service = try! JSONDecoder().decode(Service.self, from: text.data(using: .utf8)!)
                    
                     let commandDictionary = ["command": "connectPeripheral", "peripheralID": UUID().uuidString, "centralID": service.ID]
                    let jsonEncoder = JSONEncoder()
                    do {
                        vgcLogDebug("Peripheral requesting connection to service ID \(service.ID)")
                        let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                        let jsonString = String(data: jsonDataDict, encoding: .utf8)
                        self.socket.write(string: jsonString!)
                    }
                    catch {
                    }
                    
                    VgcManager.peripheral.haveConnectionToCentral = true
                    NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralDidConnectNotification), object: nil)

                    VgcManager.peripheral.gotConnectionToCentral()
                    
                    //print("App role: \(VgcManager.appRole)")
                    //let netService = NetService()
                    //var vgcService = VgcService(name: service.name, type:.Central, netService: netService)
                    //VgcManager.peripheral.browser.serviceLookup[netService] = vgcService
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralFoundService), object: vgcService)
                
                default:
                    vgcLogError("Default case")
                }
            }
            
        } catch {
            
        }
        

    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        vgcLogError("Peripheral received data")
        
        let mutableData = NSMutableData(data: data)
        
        let (element, remainingData) = VgcManager.elements.processMessage(data: mutableData)
        
        if let elementUnwrapped = element {
            VgcManager.peripheral.browser.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
        } else {
            vgcLogError("Peripheral got non-element from processMessage")
        }


    }
    
}

#endif
