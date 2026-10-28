//
//  MapPhotoViewModel.swift
//  loc
//
//  Handles photo caching and annotation image generation for map annotations.
//

import Foundation
import UIKit

@MainActor
class MapPhotoViewModel: ObservableObject {
    @Published var followedUsersPhotos: [FollowedUserPhoto] = []
    @Published var annotationImages: [String: UIImage] = [:]
    @Published var userProfilePictures: [String: UIImage] = [:]
    /// Bumped whenever annotationImages gains/changes entries (map markers refresh in place).
    @Published private(set) var imagesRevision = 0
    /// Called after each batch of avatars arrives so pins upgrade progressively.
    var onPicturesBatch: (() -> Void)?
    private var lastPhotoRefresh = Date.distantPast
    /// How many avatars each baked composite used, so partial composites get re-baked later.
    private var bakedPictureCounts: [String: Int] = [:]
    private var inFlight = Set<String>()

    private var isLoadingPhotos = false
    private(set) var hasLoadedPhotos = false
    private var currentGenerationTask: Task<Void, Never>?

    private let placeService: PlaceService

    init(placeService: PlaceService) {
        self.placeService = placeService
    }

    // MARK: - Photo Loading

    /// Loads profile photos for followed users for custom annotation views.
    func loadFollowedUsersPhotos(userId: String, currentUserPhotoUrl: URL?) async {
        guard !isLoadingPhotos else { return }
        // Foreground re-entries within 10 min reuse what we have (avoids refetch storms).
        if hasLoadedPhotos, Date().timeIntervalSince(lastPhotoRefresh) < 600 { return }
        lastPhotoRefresh = Date()

        isLoadingPhotos = true
        defer { isLoadingPhotos = false }

        do {
            var photos = try await placeService.fetchFollowedUsersPhotos(userId: userId)

            // Add current user's photo to the list
            if let photoUrl = currentUserPhotoUrl {
                let currentUserPhoto = FollowedUserPhoto(userId: userId, profilePhotoUrl: photoUrl.absoluteString)
                photos.append(currentUserPhoto)
            }

            self.followedUsersPhotos = photos
            self.hasLoadedPhotos = true

            await loadProfilePictures(from: photos)

        } catch {
            print("❌ [MapPhotoViewModel] Error loading followed users' photos: \(error)")
        }
    }

    /// Loads profile pictures from URLs into the cache, checking ProfilePhotoCache first.
    private func loadProfilePictures(from photos: [FollowedUserPhoto]) async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for photo in photos {
                guard let urlString = photo.profilePhotoUrl,
                      let url = URL(string: urlString) else { continue }

                group.addTask {
                    // Pin-size disk cache first, then the shared in-memory cache, then network.
                    if let disk = PinAvatarDiskCache.image(for: urlString) {
                        return (photo.userId, disk)
                    }
                    if let cached = await ProfilePhotoCache.shared.photo(for: photo.userId) {
                        let small = PinAvatarDiskCache.downsample(cached)
                        PinAvatarDiskCache.store(small, for: urlString)
                        return (photo.userId, small)
                    }
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        // Pins draw avatars at 30pt; decode at ~3x that, not 512px.
                        let image = ImageCacheService.decodeDownsampled(data: data, maxPixelSize: PinAvatarDiskCache.pixelSize)
                        if let image { PinAvatarDiskCache.store(image, for: urlString) }
                        return (photo.userId, image)
                    } catch {
                        print("⚠️ Failed to load image for user \(photo.userId)")
                        return (photo.userId, nil)
                    }
                }
            }

            // Publish in batches (one @Published write per batch, not per avatar) and let pins
            // upgrade progressively instead of waiting for every download.
            var batch: [String: UIImage] = [:]
            for await (userId, image) in group {
                if let image { batch[userId] = image }
                if batch.count >= 8 {
                    self.userProfilePictures.merge(batch) { _, new in new }
                    batch.removeAll()
                    onPicturesBatch?()
                }
            }
            if !batch.isEmpty {
                self.userProfilePictures.merge(batch) { _, new in new }
                onPicturesBatch?()
            }
        }
    }

    /// Loads a single external user's profile photo into the cache.
    func loadExternalUserPhoto(userId: String, photoUrl: URL) async {
        guard userProfilePictures[userId] == nil else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: photoUrl)
            if let image = ImageCacheService.decodeDownsampled(data: data, maxPixelSize: 512) {
                self.userProfilePictures[userId] = image
            }
        } catch {
            print("Failed to load external user photo: \(error)")
        }
    }

    // MARK: - Annotation Image Generation

    /// Generates combined annotation images off the main thread, merging into the existing cache.
    func generateAnnotationImages(for annotations: [PlaceAnnotation]) {
        let pictures = self.userProfilePictures
        // Only (re)bake annotations with no image yet, or whose composite now has more avatars
        // available than when it was baked. Requests in flight are skipped, never cancelled, so
        // progressive batches don't starve each other.
        let newAnnotations = annotations.filter { a in
            guard !inFlight.contains(a.id) else { return false }
            let available = a.userIds.prefix(3).filter { pictures[$0] != nil }.count
            guard available > 0 else { return false }
            return (bakedPictureCounts[a.id] ?? 0) < available
        }
        guard !newAnnotations.isEmpty else { return }
        inFlight.formUnion(newAnnotations.map(\.id))

        Task.detached(priority: .userInitiated) {
            let images = Self.renderAnnotationImages(for: newAnnotations, profilePictures: pictures)
            await MainActor.run { [weak self] in
                guard let self else { return }
                for a in newAnnotations {
                    self.inFlight.remove(a.id)
                    self.bakedPictureCounts[a.id] = a.userIds.prefix(3).filter { pictures[$0] != nil }.count
                }
                guard !images.isEmpty else { return }
                self.annotationImages.merge(images) { _, new in new }
                self.imagesRevision &+= 1
            }
        }
    }

    /// Renders annotation images on a background thread (pure computation).
    private nonisolated static func renderAnnotationImages(
        for annotations: [PlaceAnnotation],
        profilePictures: [String: UIImage]
    ) -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        for annotation in annotations {
            let pics = annotation.userIds.prefix(3).compactMap { profilePictures[$0] }
            guard !pics.isEmpty else { continue }
            result[annotation.id] = combinedCircularImage(images: pics)
        }
        return result
    }

    /// Creates a combined circular image from up to three profile pictures (nonisolated).
    private nonisolated static func combinedCircularImage(images: [UIImage]) -> UIImage {
        let totalSize = CGSize(width: 60, height: 30)
        let singleCircleSize = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: totalSize)

        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 11, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 22, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)

            func drawCircularImage(_ image: UIImage, in rect: CGRect) {
                context.cgContext.saveGState()
                let circlePath = UIBezierPath(ovalIn: rect)
                circlePath.addClip()
                image.draw(in: rect)
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(1.0)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                context.cgContext.restoreGState()
            }

            if images.count >= 3 { drawCircularImage(images[2], in: thirdRect) }
            if images.count >= 2 { drawCircularImage(images[1], in: secondRect) }
            if images.count >= 1 { drawCircularImage(images[0], in: firstRect) }
        }
    }
}

/// Small on-disk cache of pin-size avatar thumbnails, so cold launches draw photo pins
/// without re-downloading full-size profile photos.
enum PinAvatarDiskCache {
    static let pixelSize: CGFloat = 96
    private static let directory: URL? = {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = base.appendingPathComponent("pin-avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static func fileURL(for key: String) -> URL? {
        // Stable, filesystem-safe name derived from the URL string.
        var hash: UInt64 = 1469598103934665603
        for b in key.utf8 { hash = (hash ^ UInt64(b)) &* 1099511628211 }
        return directory?.appendingPathComponent(String(hash, radix: 16) + ".jpg")
    }

    static func image(for key: String) -> UIImage? {
        guard let url = fileURL(for: key), let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data, scale: 1)
    }

    static func store(_ image: UIImage, for key: String) {
        guard let url = fileURL(for: key), let data = image.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func downsample(_ image: UIImage) -> UIImage {
        let maxSide = max(image.size.width * image.scale, image.size.height * image.scale)
        guard maxSide > pixelSize else { return image }
        let ratio = pixelSize / maxSide
        let size = CGSize(width: image.size.width * image.scale * ratio, height: image.size.height * image.scale * ratio)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
}
