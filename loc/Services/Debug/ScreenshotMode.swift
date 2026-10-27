//
//  ScreenshotMode.swift
//  loc
//
//  DEBUG-only automation hooks for App Store screenshot capture (locUITests/ScreenshotTests).
//  Compiled out of Release/TestFlight/App Store builds.
//
//  Launch argument: -MesaScreenshotMode
//  Environment:
//    MESA_DEMO_EMAIL / MESA_DEMO_PASSWORD  demo account (from CI secrets; never committed)
//    MESA_SCREENSHOT_SCENE                 map | tonight | trips | profile
//                                          | pick:<id> | place:<id> | list:<id>
//

import Foundation

#if DEBUG
@MainActor
enum ScreenshotMode {
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-MesaScreenshotMode")
    }

    private static var env: [String: String] { ProcessInfo.processInfo.environment }

    /// Signs in the demo account (if no session) and opens the requested scene once the main screen is up.
    static func start(userSession: UserSession, deepLinkViewModel: DeepLinkViewModel) {
        guard isActive else { return }
        Task { @MainActor in
            if !userSession.isUserLoggedIn,
               let email = env["MESA_DEMO_EMAIL"], !email.isEmpty,
               let password = env["MESA_DEMO_PASSWORD"], !password.isEmpty {
                do {
                    _ = try await ServiceContainer.shared.authService.signIn(email: email, password: password)
                } catch {
                    print("[ScreenshotMode] demo sign-in failed")
                }
            }
            // Wait (max ~30s) for session restore / sign-in to land on the main screen.
            for _ in 0..<60 where !userSession.isUserLoggedIn {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            open(scene: env["MESA_SCREENSHOT_SCENE"] ?? "map", userSession: userSession, deepLinkViewModel: deepLinkViewModel)
        }
    }

    private static func open(scene: String, userSession: UserSession, deepLinkViewModel: DeepLinkViewModel) {
        let parts = scene.split(separator: ":", maxSplits: 1).map(String.init)
        let kind = parts.first ?? "map"
        let arg = parts.count > 1 ? parts[1] : ""
        switch kind {
        case "tonight":
            NotificationManager.shared.pendingSheet = .tonight
        case "trips":
            NotificationManager.shared.pendingSheet = .tripsList
        case "pick":
            NotificationManager.shared.pendingSheet = .groupPick(pickId: arg)
        case "place", "list":
            if let url = URL(string: "loc://\(kind)/\(arg)") {
                Task { await deepLinkViewModel.processIncomingURL(url) }
            }
        case "profile":
            let id = arg.isEmpty ? (userSession.currentUserId ?? "") : arg
            if let url = URL(string: "loc://profile/\(id)") {
                Task { await deepLinkViewModel.processIncomingURL(url) }
            }
        default:
            break // "map": the home map / map-first list view
        }
    }
}
#endif
