//
//  ScreenshotReadiness.swift
//  loc
//
//  DEBUG-only loading signals for App Store screenshot capture. The UI test reads them (through
//  ScreenshotReadinessProbe) to know when shimmers are gone and the profile photo has loaded.
//

import Foundation

#if DEBUG
@MainActor
final class ScreenshotReadiness: ObservableObject {
    static let shared = ScreenshotReadiness()

    private init() {}

    /// Number of shimmer / skeleton placeholders currently on screen.
    @Published private(set) var shimmerCount: Int = 0
    /// True once the signed-in user's profile photo is loaded into the profile and the tab icon.
    @Published var profilePhotoLoaded: Bool = false
    /// Short diagnostic about the profile photo (host or failure reason); never contains secrets.
    @Published var profilePhotoNote: String = "pending"
    /// Name of the scene the app has finished opening (empty until then).
    @Published var openedScene: String = ""

    /// Records a placeholder that appeared.
    func shimmerAppeared() { shimmerCount += 1 }

    /// Records a placeholder that went away.
    func shimmerDisappeared() { shimmerCount = max(0, shimmerCount - 1) }

    /// Compact value exposed to the UI test, e.g. "scene=list;shimmer=0;pfp=1;note=ok".
    var summary: String {
        "scene=\(openedScene);shimmer=\(shimmerCount);pfp=\(profilePhotoLoaded ? 1 : 0);note=\(profilePhotoNote)"
    }
}
#endif
