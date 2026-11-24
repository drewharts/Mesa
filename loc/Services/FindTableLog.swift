//
//  FindTableLog.swift
//  loc
//
//  Single logging entry point for the "Find a table" handoff (Explore card -> list sheet -> form),
//  so the whole path can be followed with one console filter.
//

import Foundation

enum FindTableLog {
    /// Prints a handoff trace line tagged for filtering ("[FindTable]").
    static func log(_ message: String) {
        print("🍽️ [FindTable] \(message)")
    }
}
