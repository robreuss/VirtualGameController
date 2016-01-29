//
//  VgcLogger.swift
//  
//
//  Created by Rob Reuss on 12/20/15.
//
//

import Foundation

@objc public enum LogLevel: Int, CustomStringConvertible {

    case Error = 0
    case Debug = 1
    case Verbose = 2
    
    public var description : String {
        
        switch self {
            
            case .Error: return "Error"
            case .Debug: return "Debug"
            case .Verbose: return "Verbose"
            
        }
    }
}

func logAtLevel(priority: LogLevel, logLine: String ) {
    
    if priority.rawValue <= VgcManager.loggerLogLevel.rawValue  {
        
        if VgcManager.loggerUseNSLog {
            NSLog(logLine)
        } else {
            print(logLine)
        }
        
        
    }
}

public func vgcLogVerbose(logLine: String) {
    
    logAtLevel(.Verbose, logLine: logLine)
    
}

public func vgcLogDebug(logLine: String) {

    logAtLevel(.Debug, logLine: logLine)
    
}

public func vgcLogError(logLine: String) {

    logAtLevel(.Error, logLine: "<<< ERROR >>> \(logLine)")
    
}