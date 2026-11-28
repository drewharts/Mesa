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

    /// Ids of on-screen image views still waiting for their picture.
    private var pendingImages: Set<UUID> = []
    /// Ids of on-screen photo tiles showing a generated placeholder (no photo) instead of a real image.
    private var emptyTiles: Set<UUID> = []
    /// Image URLs that finished loading with an error (diagnostic only).
    @Published private(set) var failedImageCount: Int = 0
    /// Number of screenshot-mode preparation jobs (cover verification, Tonight filtering) still running.
    @Published private(set) var busyJobs: Int = 0
    /// Bumped whenever the image sets change, so the probe re-publishes.
    @Published private(set) var imageRevision: Int = 0

    /// Marks an image view as waiting (true) or settled (false).
    func setImagePending(_ id: UUID, _ pending: Bool) {
        let changed = pending ? pendingImages.insert(id).inserted : pendingImages.remove(id) != nil
        if changed { imageRevision += 1 }
    }

    /// Marks a photo tile as showing a placeholder (true) or a real photo (false).
    func setTileEmpty(_ id: UUID, _ empty: Bool) {
        let changed = empty ? emptyTiles.insert(id).inserted : emptyTiles.remove(id) != nil
        if changed { imageRevision += 1 }
    }

    /// Records one image that failed to load.
    func imageFailed() { failedImageCount += 1 }

    /// Marks the start of a background preparation job that must finish before capture.
    func beginJob() { busyJobs += 1 }

    /// Marks the end of a background preparation job.
    func endJob() { busyJobs = max(0, busyJobs - 1) }

    /// True when every visible image is loaded, no tile shows a placeholder, no shimmer is up and no job is running.
    var imagesAllLoaded: Bool { pendingImages.isEmpty && emptyTiles.isEmpty && shimmerCount == 0 && busyJobs == 0 }

    /// Records a placeholder that appeared.
    func shimmerAppeared() { shimmerCount += 1 }

    /// Records a placeholder that went away.
    func shimmerDisappeared() { shimmerCount = max(0, shimmerCount - 1) }

    /// Compact value exposed to the UI test, e.g. "scene=list;shimmer=0;pfp=1;note=ok".
    var summary: String {
        "scene=\(openedScene);shimmer=\(shimmerCount);images=\(imagesAllLoaded ? 1 : 0);pending=\(pendingImages.count);empty=\(emptyTiles.count);failed=\(failedImageCount);jobs=\(busyJobs);pfp=\(profilePhotoLoaded ? 1 : 0);note=\(profilePhotoNote)"
    }
}
#endif
