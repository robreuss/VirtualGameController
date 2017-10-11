//
//  Dispatcher.swift
//  VGC_ServerPackageDescription
//
//  Created by Rob Reuss on 10/9/17.
//
//
// Sequence:
// Central registers
// Peripheral requests table of Centrals
// Peripheral connects to Central -> Some kind of socket matching mechanism
// Notification to Central of Peripheral connection -> Some kind of identity for the Peripheral
// Peripheral starts sending elements somehow tagged with peripheral or central info

import Foundation
import Vapor

class Dispatcher {
    
    var centrals: [Central]
   
    init() {
        centrals = []      // [CentralID, CentralSocket
    }
    
    func listOfCentrals() -> [String] {
        
        let centralNames = centrals.map { $0.ID }
        return centralNames as! [String]

    }
    
    func registerCentral(centralID: String, webSocket: WebSocket) {
        
        let central = Central()
        central.ID = centralID
        central.name = "Test name"
        central.socket = webSocket
        centrals.append(central)

    }
    
    func deregisterCentral(centralID: String) {
        
        
        
    }
    

    /*
    func sendElement(peripheralID: String, elementDataString: String) {
        
        if let centralID = peripheralToCentral[peripheralID] {
            if let centralSocket = centralToSocket[centralID] {
                try? centralSocket.send(elementDataString)
            }
        }
        
    }
    */
}
