@_exported import Vapor
import Foundation

let dispatcher = Dispatcher()
var function: Function = .Central
var centrals = [String: Central]()
var peripherals = [Peripheral]()

class Central {
    
    var ID: String?
    var name: String?
    var socket: WebSocket?
    
}

class Peripheral {
    
    var ID: String?
    var centralID: String?
    var name: String?
    var socket: WebSocket?
    var centralSocket: WebSocket?
    
}

@objc public enum Function: Int {
    
    case Central
    case Peripheral
    
}

extension Droplet {
    
    public func setup() throws {
        try setupRoutes()

        get("plaintext") { req in
            return "Hello, world!"
        }
        
        socket("sendElement") { req, ws in
            
            var pingTimer: DispatchSourceTimer? = nil
            
            pingTimer = DispatchSource.makeTimerSource()
            pingTimer?.scheduleRepeating(deadline: .now(), interval: .seconds(25))
            pingTimer?.setEventHandler { try? ws.ping() }
            pingTimer?.resume()
            
            ws.onText = { ws, text in

                try? ws.send(text.makeBytes())

            }
            
            ws.onClose = { ws, _, _, _ in
                pingTimer?.cancel()
                pingTimer = nil

            }
        }
        
        socket("registerAsCentral") { req, ws in
            
            function = .Central
            
            var pingTimer: DispatchSourceTimer? = nil
            
            pingTimer = DispatchSource.makeTimerSource()
            pingTimer?.scheduleRepeating(deadline: .now(), interval: .seconds(25))
            pingTimer?.setEventHandler { try? ws.ping() }
            pingTimer?.resume()
            
            ws.onText = { ws, text in
                
                let json = try JSON(bytes: text.makeBytes())
                
                print("Received central registraiton json: \(json)")
                let central = Central()
                if let centralID = (json.object?["centralID"]?.string) {
                    central.ID = centralID
                    central.name = "Central name"
                    central.socket = ws
                    centrals[centralID] = central
                } else {
                    print("Attempted central registration, no CentralID")
                }
                
            }
            
            ws.onClose = { ws, _, _, _ in
                pingTimer?.cancel()
                pingTimer = nil
                
            }
        }
        
        socket("connectPeripheral") { req, ws in
            
            function = .Peripheral
            
            var pingTimer: DispatchSourceTimer? = nil
            
            pingTimer = DispatchSource.makeTimerSource()
            pingTimer?.scheduleRepeating(deadline: .now(), interval: .seconds(25))
            pingTimer?.setEventHandler { try? ws.ping() }
            pingTimer?.resume()
            
            ws.onText = { ws, text in
                
                let json = try JSON(bytes: text.makeBytes())
                let peripheral = Peripheral()
                if let peripheralID = (json.object?["peripheralID"]?.string) {
                    peripheral.ID = peripheralID
                    peripheral.name = "Peripheral name"
                    peripheral.socket = ws
                    if let centralID = (json.object?["centralID"]?.string) {
                        peripheral.centralID = centralID
                        peripheral.centralSocket = centrals[centralID]?.socket
                        peripherals.append(peripheral)
                    }

                }
                
            }
            
            ws.onClose = { ws, _, _, _ in
                pingTimer?.cancel()
                pingTimer = nil
                
            }
        }
        
        socket("getCentralList") { req, ws in
            
            var pingTimer: DispatchSourceTimer? = nil
            
            pingTimer = DispatchSource.makeTimerSource()
            pingTimer?.scheduleRepeating(deadline: .now(), interval: .seconds(25))
            pingTimer?.setEventHandler { try? ws.ping() }
            pingTimer?.resume()
            
            var centralList = [String: String]() // Central Name, Central ID
            for centralID in centrals.keys {
                centralList[centralID] = centrals[centralID]?.name
            }

            ws.onText = { ws, text in
                let encoder = JSONEncoder()
                let json = try encoder.encode(centralList)
                try? ws.send(json.makeBytes())
            }
            
            ws.onClose = { ws, _, _, _ in
                pingTimer?.cancel()
                pingTimer = nil
                
            }
        }



    }
}
