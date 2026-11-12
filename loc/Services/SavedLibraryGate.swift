//
//  SavedLibraryGate.swift
//  loc
//
//  PROTOTYPE gate for the auto-sorted "Saved (beta)" library. All three must hold:
//    1. the signed-in user is Mesa's admin (Drew),
//    2. the build is TestFlight (or a debug build), never an App Store build,
//    3. the PostHog flag `auto_sort_saved` is on (off when PostHog is unavailable).
//

import Foundation

enum SavedLibraryGate {
    static let flagKey = "auto_sort_saved"
    /// Same admin id the approval-queue work uses (Drew's users.id).
    static let adminUserId = "C9DFA19E-B1B0-4EF1-8697-E448BC606CC7"

    static func isAdmin(_ userId: String?) -> Bool {
        userId?.uppercased() == adminUserId
    }

    /// True for TestFlight and debug builds. App Store builds have a production receipt and the
    /// production backend URL (only the TestFlight workflow overrides MESA_API_BASE_URL to staging).
    static var isTestFlightOrDebug: Bool {
        #if DEBUG
        return true
        #else
        let sandboxReceipt = Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        let nonProductionBackend = MesaBackendConfig.baseURL != MesaBackendConfig.productionBaseURL
        return sandboxReceipt || nonProductionBackend
        #endif
    }

    /// Cheap synchronous check using the flags PostHog already has cached.
    static func isEnabled(userId: String?) -> Bool {
        isAdmin(userId) && isTestFlightOrDebug && Analytics.isFeatureEnabled(flagKey)
    }

    /// Refreshes flags (bounded to a few seconds) and then checks. Skips the network for everyone else.
    @MainActor
    static func resolve(userId: String?) async -> Bool {
        guard isAdmin(userId), isTestFlightOrDebug else { return false }
        // Whichever comes first: flags reloaded, or 5 seconds. Both callbacks run on the main queue.
        let once = ResumeOnce()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            once.continuation = continuation
            Analytics.reloadFeatureFlags { once.resume() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { once.resume() }
        }
        return isEnabled(userId: userId)
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
