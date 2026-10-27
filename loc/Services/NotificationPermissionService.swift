//
//  NotificationPermissionService.swift
//  loc
//
//  Single Responsibility: decides WHEN to ask for notification permission.
//  The system prompt is no longer shown cold at launch. It appears at the moment it is obviously
//  useful (the user just started importing a video and can now leave the app), with a launch-count
//  fallback so people who never import still get asked about social notifications.
//

import Foundation
import UIKit
import UserNotifications

@MainActor
final class NotificationPermissionService {
    static let shared = NotificationPermissionService()
    private init() {}

    private let launchCountKey = "NotificationPermission.launchCount"
    /// If the user hasn't imported anything, ask on this launch so follow/comment pushes still work.
    private let fallbackPromptLaunch = 3

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Called from AppDelegate at launch. Registers for remote notifications if already allowed;
    /// otherwise only prompts once the user has opened the app a few times.
    func handleLaunch() async {
        let launches = UserDefaults.standard.integer(forKey: launchCountKey) + 1
        UserDefaults.standard.set(launches, forKey: launchCountKey)

        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
        case .notDetermined:
            if launches >= fallbackPromptLaunch {
                _ = await requestIfNeeded(context: "launch_fallback")
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    /// Shows the system prompt if the user hasn't decided yet, and registers for remote
    /// notifications on success. Returns whether notifications are allowed afterwards.
    @discardableResult
    func requestIfNeeded(context: String) async -> Bool {
        switch await authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            UIApplication.shared.registerForRemoteNotifications()
            return true
        case .denied:
            return false
        case .notDetermined:
            Analytics.track(.notificationPermissionPrompted, ["context": context])
            let granted = (try? await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            if granted { UIApplication.shared.registerForRemoteNotifications() }
            return granted
        @unknown default:
            return false
        }
    }
}
