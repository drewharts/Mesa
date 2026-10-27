//
//  AnalyticsService.swift
//  loc
//
//  Thin wrapper around PostHog for product analytics (screen flows, funnels, retention).
//  The API key comes from the POSTHOG_API_KEY build setting (Secrets.xcconfig, written by CI
//  from a GitHub secret) via Info.plist. If the key is missing, every call is a no-op.
//

import Foundation
import PostHog

enum Analytics {
    private static var isEnabled = false

    /// Call once at launch.
    static func setup() {
        let info = Bundle.main.infoDictionary
        let key = (info?["PostHogApiKey"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        let host = (info?["PostHogHost"] as? String)?.trimmingCharacters(in: .whitespaces) ?? ""
        // Unset build settings arrive as "" or the literal "$(POSTHOG_API_KEY)".
        guard !key.isEmpty, !key.hasPrefix("$(") else { return }
        let config = PostHogConfig(apiKey: key, host: (host.isEmpty || host.hasPrefix("$(")) ? "https://us.i.posthog.com" : host)
        config.captureScreenViews = true          // automatic screen views
        config.captureApplicationLifecycleEvents = true // Application Opened / Backgrounded / Installed
        PostHogSDK.shared.setup(config)
        isEnabled = true
    }

    static func identify(userId: String) {
        guard isEnabled, !userId.isEmpty else { return }
        PostHogSDK.shared.identify(userId.lowercased())
    }

    static func reset() {
        guard isEnabled else { return }
        PostHogSDK.shared.reset()
    }

    static func track(_ event: Event, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.capture(event.rawValue, properties: properties)
    }

    /// Manual screen event for SwiftUI screens (auto-capture only sees UIKit view controllers).
    static func screen(_ name: String, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        PostHogSDK.shared.screen(name, properties: properties)
    }

    enum Event: String {
        case importStarted = "import_started"
        case importFinished = "import_finished"
        case importBackgrounded = "import_backgrounded"
        case importNotificationShown = "import_notification_shown"
        case importNotificationOpened = "import_notification_opened"
        case importSavedToList = "import_saved_to_list"
        case notificationPermissionPrompted = "notification_permission_prompted"
        case placeSaved = "place_saved"
        case listCreated = "list_created"
        case listShared = "list_shared"
        case placeShared = "place_shared"
        case profileShared = "profile_shared"
        case profileViewed = "profile_viewed"
        case tripOpened = "trip_opened"
        case tonightOpened = "tonight_opened"
        case navTapped = "nav_tapped"
        case tonightResultsShown = "tonight_results_shown"
        case groupPickCreated = "group_pick_created"
        case groupPickVoted = "group_pick_voted"
        case groupPickDecided = "group_pick_decided"
    }
}
