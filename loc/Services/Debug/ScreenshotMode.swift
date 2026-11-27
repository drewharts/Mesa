//
//  ScreenshotMode.swift
//  loc
//
//  DEBUG-only automation hooks for App Store screenshot capture (locUITests/ScreenshotTests).
//  Compiled out of Release/TestFlight/App Store builds. Read-only: it signs in, loads and views;
//  it never writes app data.
//
//  Launch argument: -MesaScreenshotMode
//  Environment:
//    MESA_DEMO_EMAIL / MESA_DEMO_PASSWORD  demo account (from CI secrets; never committed)
//    MESA_SCREENSHOT_SCENE                 map | explore | list:<id> | place:<id>:<name> | trips:<id>
//                                          | profile | tonight
//

import Foundation
import UIKit

#if DEBUG
@MainActor
enum ScreenshotMode {
    static var isActive: Bool { ScreenshotPrivacy.isActive }

    private static var env: [String: String] { ProcessInfo.processInfo.environment }
    private static var hasStarted = false

    /// Signs in the demo account (if no session), loads the profile photo and opens the requested scene.
    static func start(
        userSession: UserSession,
        profileViewModel: ProfileViewModel,
        deepLinkViewModel: DeepLinkViewModel,
        dataManager: DataManager
    ) {
        guard isActive, !hasStarted else { return }
        hasStarted = true
        suppressPopups()
        Task { @MainActor in
            await waitForLogin(userSession, seconds: 8)
            if !userSession.isUserLoggedIn {
                await signInDemoAccount(userSession: userSession, dataManager: dataManager)
            }
            await waitForLogin(userSession, seconds: 40)
            ScreenshotPrivacy.currentUserId = userSession.currentUserId
            await loadProfilePhoto(userSession: userSession, profileViewModel: profileViewModel, dataManager: dataManager)
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            let scene = env["MESA_SCREENSHOT_SCENE"] ?? "map"
            await open(scene: scene, userSession: userSession, deepLinkViewModel: deepLinkViewModel)
            ScreenshotReadiness.shared.openedScene = scene.split(separator: ":").first.map(String.init) ?? scene
        }
    }

    /// Marks first-run popups as already seen so they never cover a screenshot.
    private static func suppressPopups() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "hasSeenPhotoImportTooltip")
        defaults.set(true, forKey: "hasSeenSuggestedProfilesPopup")
        defaults.set(true, forKey: "hasSeenDiscoverySheet")
    }

    /// Polls until the session reports a signed-in user or the time runs out.
    private static func waitForLogin(_ userSession: UserSession, seconds: Int) async {
        for _ in 0..<(seconds * 2) where !userSession.isUserLoggedIn {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    }

    /// Signs in with the demo credentials and begins the app session (read-only: resolves the user row, writes nothing).
    private static func signInDemoAccount(userSession: UserSession, dataManager: DataManager) async {
        guard let email = env["MESA_DEMO_EMAIL"], !email.isEmpty,
              let password = env["MESA_DEMO_PASSWORD"], !password.isEmpty else { return }
        do {
            let session = try await ServiceContainer.shared.authService.signIn(email: email, password: password)
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

    // MARK: - Profile Photo

    /// Waits for the profile, then loads the user's photo into the profile page and the tab icon, retrying on failure.
    private static func loadProfilePhoto(
        userSession: UserSession,
        profileViewModel: ProfileViewModel,
        dataManager: DataManager
    ) async {
        let readiness = ScreenshotReadiness.shared
        guard let uid = userSession.currentUserId else { readiness.profilePhotoNote = "nouid"; return }
        for _ in 0..<40 where profileViewModel.user == nil {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        if profileViewModel.user == nil { await dataManager.loadProfileData(userId: uid) }
        guard let url = profileViewModel.user?.profilePhotoURL else { readiness.profilePhotoNote = "nourl"; return }
        for attempt in 1...5 {
            readiness.profilePhotoNote = "try\(attempt)@\(url.host ?? "?")"
            if let image = await downloadPhoto(url) {
                profileViewModel.userPicture = image
                await ProfilePhotoCache.shared.loadPhoto(userId: uid, photoURL: url)
                if ProfilePhotoCache.shared.photo(for: uid) != nil {
                    readiness.profilePhotoNote = "ok"
                    readiness.profilePhotoLoaded = true
                    return
                }
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
        readiness.profilePhotoNote = "failed@\(url.host ?? "?")"
    }

    /// Downloads and decodes a photo, returning nil on any failure.
    private static func downloadPhoto(_ url: URL) async -> UIImage? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode ?? 200 < 400 else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Scenes

    /// Opens the scene named by `scene` ("kind" or "kind:arg[:arg2]").
    private static func open(scene: String, userSession: UserSession, deepLinkViewModel: DeepLinkViewModel) async {
        let parts = scene.split(separator: ":", maxSplits: 2).map(String.init)
        let kind = parts.first ?? "map"
        let arg = parts.count > 1 ? parts[1] : ""
        switch kind {
        case "map": await present(.myPlaces)
        case "explore": AppTabRouter.shared.select(.explore)
        case "profile": AppTabRouter.shared.select(.profile)
        case "tonight": await present(.tonight)
        case "list": await present(.list(listId: arg))
        case "trips": await openTrip(id: arg)
        case "place":
            let name = parts.count > 2 ? parts[2] : "Place"
            var components = URLComponents(string: "loc://place/\(arg)")
            components?.queryItems = [URLQueryItem(name: "name", value: name)]
            if let url = components?.url { await deepLinkViewModel.processIncomingURL(url) }
        default:
            break
        }
    }

    /// Switches to the Trips tab and opens a trip's itinerary over the map.
    private static func openTrip(id: String) async {
        AppTabRouter.shared.select(.trips)
        try? await Task.sleep(nanoseconds: 4_000_000_000)
        NotificationManager.shared.pendingTripId = id
    }

    /// Presents a map sheet and re-presents it if launch-time UI dismisses it.
    private static func present(_ sheet: AppSheetType) async {
        for _ in 0..<4 {
            if PresentationService.shared.activeSheet != sheet {
                PresentationService.shared.present(sheet)
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
}
#endif
