//
//  VgcLogger.swift
//  
//
//  Created by Rob Reuss on 12/20/15.
//
//

import Foundation

// Default to error for release mode
public var logLevel = LogLevel.Error
public var useNSLog = false

public enum LogLevel: Int, CustomStringConvertible {
    
    case Verbose
    case Debug
    case Error
    
    public var description : String {
        
        switch self {
        case .Verbose: return "Verbose"
        case .Debug: return "Debug"
        case .Error: return "Error"
        }
    }
}

func logAtLevel(priority: LogLevel, logLine: String ) {
    
    if logLevel == priority {
        
        if useNSLog {
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

    logAtLevel(.Error, logLine: logLine)
    
}