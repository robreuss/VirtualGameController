//
//  VgcLogger.swift
//  
//
//  Created by Rob Reuss on 12/20/15.
//
//

import Foundation

@objc public enum LogLevel: Int, CustomStringConvertible {

    case error = 0
    case debug = 1
    case verbose = 2
    
    public var description : String {
        
        switch self {
            
            case .error: return "Error"
            case .debug: return "Debug"
            case .verbose: return "Verbose"
            
        }
    }
}

func logAtLevel(_ priority: LogLevel, logLine: String ) {
    
    if priority.rawValue <= VgcManager.loggerLogLevel.rawValue  {
        
        if VgcManager.loggerUseNSLog {
            NSLog(logLine)
        } else {
            print(logLine)
        }
        
        
    }
}

public func vgcLogVerbose(_ logLine: String) {
    
    logAtLevel(.verbose, logLine: logLine)
    
}

public func vgcLogDebug(_ logLine: String) {

    logAtLevel(.debug, logLine: logLine)
    
}

public func vgcLogError(_ logLine: String) {

    logAtLevel(.error, logLine: "<<< ERROR >>> \(logLine)")
    
}
