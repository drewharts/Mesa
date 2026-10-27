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
    static func start(userSession: UserSession, deepLinkViewModel: DeepLinkViewModel, dataManager: DataManager) {
        guard isActive else { return }
        Task { @MainActor in
            if !userSession.isUserLoggedIn,
               let email = env["MESA_DEMO_EMAIL"], !email.isEmpty,
               let password = env["MESA_DEMO_PASSWORD"], !password.isEmpty {
                do {
                    let session = try await ServiceContainer.shared.authService.signIn(email: email, password: password)
                    // Same post-auth step as LoginViewModel: resolve the app user row, then begin the session.
                    struct Row: Decodable { let id: String }
                    let authId = session.user.id.uuidString
                    let rows: [Row] = try await SupabaseManager.shared.client
                        .from("users").select("id")
                        .or("supabase_uid.eq.\(authId),supabase_uid.eq.\(authId.lowercased())")
                        .limit(1).execute().value
                    let uid = rows.first?.id ?? authId
                    ScreenshotPrivacy.currentUserId = uid
                    await userSession.beginSession(uid: uid)
                    await dataManager.initializeProfileData(userId: uid)
                } catch {
                    print("[ScreenshotMode] demo sign-in failed")
                }
            }
            // Wait (max ~30s) for session restore / sign-in to land on the main screen.
            for _ in 0..<60 where !userSession.isUserLoggedIn {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
            ScreenshotPrivacy.currentUserId = userSession.currentUserId
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            await open(scene: env["MESA_SCREENSHOT_SCENE"] ?? "map", userSession: userSession, deepLinkViewModel: deepLinkViewModel)
        }
    }

    private static func open(scene: String, userSession: UserSession, deepLinkViewModel: DeepLinkViewModel) async {
        let parts = scene.split(separator: ":", maxSplits: 1).map(String.init)
        let kind = parts.first ?? "map"
        let arg = parts.count > 1 ? parts[1] : ""
        switch kind {
        case "tonight": await present(.tonight)
        case "trips": await present(.tripsList)
        case "pick": await present(.groupPick(pickId: arg))
        case "list": await present(.list(listId: arg))
        case "place":
            struct P: Decodable { let name: String }
            let rows: [P] = (try? await SupabaseManager.shared.client
                .from("places").select("name").eq("id", value: arg).limit(1).execute().value) ?? []
            var c = URLComponents(string: "loc://place/\(arg)")!
            c.queryItems = [URLQueryItem(name: "name", value: rows.first?.name ?? "Place")]
            if let url = c.url { await deepLinkViewModel.processIncomingURL(url) }
        case "profile":
            let id = arg.isEmpty ? (userSession.currentUserId ?? "") : arg
            if let url = URL(string: "loc://profile/\(id)") {
                await deepLinkViewModel.processIncomingURL(url)
            }
        default:
            break // "map": the home map / map-first list view
        }
    }

    /// Presents a sheet and re-presents it if launch-time UI dismisses it.
    private static func present(_ sheet: AppSheetType) async {
        for _ in 0..<5 {
            if PresentationService.shared.activeSheet != sheet {
                PresentationService.shared.present(sheet)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
#endif

/// Privacy masking for App Store screenshots. Always false outside DEBUG screenshot runs.
enum ScreenshotPrivacy {
    static let isActive: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-MesaScreenshotMode")
        #else
        return false
        #endif
    }()

    /// The signed-in account (its own name stays real).
    static var currentUserId: String?

    private static let neutral = ["Sam", "Alex", "Jordan", "Taylor", "Riley", "Casey"]

    /// Replaces another person's name with a stable neutral one during screenshot runs.
    static func name(_ real: String, userId: String?) -> String {
        guard isActive else { return real }
        if let me = currentUserId, let id = userId, me.lowercased() == id.lowercased() { return real }
        let key = (userId ?? real).lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return neutral[key % neutral.count]
    }
}
