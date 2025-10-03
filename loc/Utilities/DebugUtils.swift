//
//  DebugUtils.swift
//  loc
//
//  Created by Mesa on 10/1/25.
//

import Foundation

// Debug logging flag - set to true for verbose logging, false for production
private let DEBUG_LOGGING = {
    #if DEBUG
        return true
    #else
        return false
    #endif
}()

/// Global debug logging function - only prints in DEBUG builds
func debugLog(_ message: String) {
    if DEBUG_LOGGING {
        print(message)
    }
}
