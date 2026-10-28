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
import SwiftUI

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
        // SwiftUI screens show up as hosting-controller class names, so screens are sent manually
        // via `.analyticsScreen("Name")` instead.
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = true // Application Opened / Backgrounded / Installed
        // Session replay. Screenshot mode is required for SwiftUI; text inputs and images are
        // masked (views can opt in further with `.postHogMask()`).
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false   // place photos are the point of the app
        config.sessionReplayConfig.maskAllSandboxedViews = true
        // Crash / exception autocapture (also gated by the project's error tracking setting).
        config.errorTrackingConfig.autoCapture = true
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
        if name.hasPrefix("Onboarding") || name == "Login" || name == "Splash" {
            track(.onboardingStep, ["step": name])
        }
    }

    /// Sends `event` at most once per `interval` seconds per key (for high-frequency map events).
    private static var lastSent: [String: Date] = [:]
    private static let throttleLock = NSLock()
    static func trackThrottled(_ event: Event, key: String? = nil, every interval: TimeInterval, _ properties: [String: Any] = [:]) {
        guard isEnabled else { return }
        let k = key ?? event.rawValue
        let now = Date()
        throttleLock.lock()
        if let last = lastSent[k], now.timeIntervalSince(last) < interval { throttleLock.unlock(); return }
        lastSent[k] = now
        throttleLock.unlock()
        track(event, properties)
    }

    enum Event: String {
        case importStarted = "import_started"
        case importFinished = "import_finished"
        case importBackgrounded = "import_backgrounded"
        case importNotificationShown = "import_notification_shown"
        case importNotificationOpened = "import_notification_opened"
        case importSavedToList = "import_saved_to_list"
        case importPlaceCorrected = "import_place_corrected"
        case notificationPermissionPrompted = "notification_permission_prompted"
        case placeSaved = "place_saved"
        case listCreated = "list_created"
        case listShared = "list_shared"
        case listOpened = "list_opened"
        case listSheetHeightChanged = "list_sheet_height_changed"
        case listPlaceSelected = "list_place_selected"
        case placeShared = "place_shared"
        case profileShared = "profile_shared"
        case profileViewed = "profile_viewed"
        case tripOpened = "trip_opened"
        case pastTripsExpanded = "past_trips_expanded"
        case tonightOpened = "tonight_opened"
        case navTapped = "nav_tapped"
        case tonightResultsShown = "tonight_results_shown"
        case groupPickCreated = "group_pick_created"
        case groupPickVoted = "group_pick_voted"
        case groupPickDecided = "group_pick_decided"
        case groupPickResultViewed = "group_pick_result_viewed"
        case groupPickDirectionsTapped = "group_pick_directions_tapped"
        case groupPickPlaceOpened = "group_pick_place_opened"
        case groupPickMoreOptions = "group_pick_more_options"
        case groupPickPlaceAdded = "group_pick_place_added"
        case groupPickInvited = "group_pick_invited"
        case groupPickPushOpened = "group_pick_push_opened"
        case groupPickActionFailed = "group_pick_action_failed"
        case tonightMoreOptions = "tonight_more_options"
        case tonightPicksRowShown = "tonight_picks_row_shown"
        case tonightPicksRowTapped = "tonight_picks_row_tapped"
        case tonightEmpty = "tonight_empty"
        case mapPinsRendered = "map_pins_rendered"
        case mapCameraIdle = "map_camera_idle"
        case onboardingStep = "onboarding_step"
        case signInFailed = "sign_in_failed"
        case placesInViewEmpty = "places_in_view_empty"
        case placePeekOpened = "place_peek_opened"
    }
}

extension View {
    /// Sends a readable PostHog screen event each time this view appears.
    func analyticsScreen(_ name: String, _ properties: [String: Any] = [:]) -> some View {
        onAppear { Analytics.screen(name, properties) }
    }
}
