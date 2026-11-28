//
//  ScreenshotPrivacy.swift
//  loc
//
//  Privacy masking for App Store screenshots: other people's names become neutral first names and
//  their faces are hidden. Always inactive outside DEBUG builds launched with -MesaScreenshotMode.
//

import Foundation

enum ScreenshotPrivacy {
    /// True only in a DEBUG build launched for screenshot capture.
    static let isActive: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-MesaScreenshotMode")
        #else
        return false
        #endif
    }()

    /// The signed-in account (its own name and photo stay real).
    static var currentUserId: String?

    private static let neutral = ["Sam", "Alex", "Jordan", "Taylor", "Riley", "Casey"]

    /// Returns true when the given user id is the signed-in account.
    static func isCurrentUser(_ userId: String?) -> Bool {
        guard let me = currentUserId, let id = userId else { return false }
        return me.caseInsensitiveCompare(id) == .orderedSame
    }

    /// Replaces another person's name with a stable neutral one during screenshot runs.
    static func name(_ real: String, userId: String?) -> String {
        guard isActive, !isCurrentUser(userId) else { return real }
        let key = (userId ?? real).lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return neutral[key % neutral.count]
    }

    /// Returns the photo URL to show for a user: nil (placeholder avatar) for other people during screenshot runs.
    static func photoURL(_ real: String?, userId: String?) -> String? {
        guard isActive, !isCurrentUser(userId) else { return real }
        return nil
    }
}
