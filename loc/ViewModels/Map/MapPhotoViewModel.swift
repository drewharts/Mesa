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

    private var isLoadingPhotos = false
    private(set) var hasLoadedPhotos = false

    private let placeService: PlaceService

    init(placeService: PlaceService) {
        self.placeService = placeService
    }

    // MARK: - Photo Loading

    /// Loads profile photos for followed users for custom annotation views.
    func loadFollowedUsersPhotos(userId: String, currentUserPhotoUrl: URL?) async {
        guard !isLoadingPhotos else { return }

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

    /// Loads profile pictures from URLs into the cache.
    private func loadProfilePictures(from photos: [FollowedUserPhoto]) async {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for photo in photos {
                guard let urlString = photo.profilePhotoUrl,
                      let url = URL(string: urlString) else { continue }

                group.addTask {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        return (photo.userId, UIImage(data: data))
                    } catch {
                        print("⚠️ Failed to load image for user \(photo.userId)")
                        return (photo.userId, nil)
                    }
                }
            }

            for await (userId, image) in group {
                if let image = image {
                    self.userProfilePictures[userId] = image
                }
            }
        }
    }

    /// Loads a single external user's profile photo into the cache.
    func loadExternalUserPhoto(userId: String, photoUrl: URL) async {
        guard userProfilePictures[userId] == nil else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: photoUrl)
            if let image = UIImage(data: data) {
                self.userProfilePictures[userId] = image
            }
        } catch {
            print("Failed to load external user photo: \(error)")
        }
    }

    // MARK: - Annotation Image Generation

    /// Generates combined annotation images for the given annotations.
    func generateAnnotationImages(for annotations: [PlaceAnnotation]) {
        for annotation in annotations {
            let profilePictures = annotation.userIds.prefix(3).compactMap { userProfilePictures[$0] }

            guard !profilePictures.isEmpty else {
                continue
            }

            let combinedImage: UIImage
            switch profilePictures.count {
            case 1:
                combinedImage = combinedCircularImage(image1: profilePictures[0])
            case 2:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1])
            case 3:
                combinedImage = combinedCircularImage(image1: profilePictures[0], image2: profilePictures[1], image3: profilePictures[2])
            default:
                continue
            }

            annotationImages[annotation.id] = combinedImage
        }
    }

    /// Creates a combined circular image from up to three profile pictures.
    private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
        let totalSize = CGSize(width: 60, height: 30)
        let singleCircleSize = CGSize(width: 30, height: 30)
        let renderer = UIGraphicsImageRenderer(size: totalSize)

        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 11, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 22, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)

            func drawCircularImage(_ image: UIImage?, in rect: CGRect) {
                guard let image = image else { return }
                context.cgContext.saveGState()
                let circlePath = UIBezierPath(ovalIn: rect)
                circlePath.addClip()
                image.draw(in: rect)
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(1.0)
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                context.cgContext.restoreGState()
            }

            if image3 != nil { drawCircularImage(image3, in: thirdRect) }
            if image2 != nil { drawCircularImage(image2, in: secondRect) }
            if image1 != nil { drawCircularImage(image1, in: firstRect) }
        }
    }
}
