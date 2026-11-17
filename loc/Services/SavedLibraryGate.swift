//
//  SavedLibraryGate.swift
//  loc
//
//  Gate for the auto-sorted "Saved" library. On for every user by default. The PostHog flag
//  `auto_sort_saved` is only a kill switch: setting it to false for a user turns auto-sort off
//  (the bookmark opens the list picker again). A missing flag, unloaded flags or PostHog being
//  unavailable all leave auto-sort on.
//

import Foundation

enum SavedLibraryGate {
    static let flagKey = "auto_sort_saved"

    /// Cheap synchronous check using the flags PostHog already has cached.
    static var isEnabled: Bool {
        !Analytics.isFeatureExplicitlyDisabled(flagKey)
    }

    /// Refreshes flags (bounded to a few seconds) and then checks the kill switch.
    @MainActor
    static func resolve() async -> Bool {
        // Whichever comes first: flags reloaded, or 5 seconds. Both callbacks run on the main queue.
        let once = ResumeOnce()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            once.continuation = continuation
            Analytics.reloadFeatureFlags { once.resume() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { once.resume() }
        }
        return isEnabled
    }
}

/// Resumes a continuation exactly once (both callers are on the main queue).
private final class ResumeOnce: @unchecked Sendable {
    var continuation: CheckedContinuation<Void, Never>?

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
