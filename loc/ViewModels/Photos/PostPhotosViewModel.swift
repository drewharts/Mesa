//
//  PostPhotosViewModel.swift
//  loc
//
//  Manages loading of individual post photos (UIImage) and user profile photos.
//  Extracted from PlacePhotosViewModel for single-responsibility compliance.
//

import Foundation
import UIKit

@MainActor
class PostPhotosViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private var reviewPhotos: [String: [UIImage]] = [:]
    @Published private var reviewPhotoLoadingStates: [String: LoadingState] = [:]
    @Published private var userProfilePhotos: [String: UIImage] = [:]
    @Published private var profilePhotoLoadingStates: [String: LoadingState] = [:]

    // MARK: - Loading State Enum
    enum LoadingState: Equatable {
        case idle
        case loading
        case loaded
        case error(Error)

        static func == (lhs: LoadingState, rhs: LoadingState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.loading, .loading), (.loaded, .loaded):
                return true
            case (.error, .error):
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Post Photos

    /// Loads photos for a specific post (loads first 4 initially for performance).
    func loadPostPhotos(for post: PlacePost) {
        let postId = post.id
        guard !post.images.isEmpty else {
            reviewPhotos[postId] = []
            reviewPhotoLoadingStates[postId] = .loaded
            return
        }

        reviewPhotoLoadingStates[postId] = .loading
        let initialImageUrls = Array(post.images.prefix(min(4, post.images.count)))

        Task {
            let loadedImages = await loadImagesInParallel(from: initialImageUrls)
            self.reviewPhotos[postId] = loadedImages
            self.reviewPhotoLoadingStates[postId] = .loaded
        }
    }

    /// Loads more photos for a specific post when user scrolls.
    func loadMorePostPhotos(for postId: String, allImageUrls: [String]) {
        guard let currentPhotos = reviewPhotos[postId],
              currentPhotos.count < allImageUrls.count else {
            return
        }

        let startIndex = currentPhotos.count
        let urlsToLoad = Array(allImageUrls[startIndex..<min(startIndex + 4, allImageUrls.count)])

        Task {
            let newImages = await loadImagesInParallel(from: urlsToLoad)
            let existingPhotos = self.reviewPhotos[postId] ?? []
            self.reviewPhotos[postId] = existingPhotos + newImages
        }
    }

    /// Loads images in parallel from URLs, returning them in the same order as the input URLs.
    private func loadImagesInParallel(from urls: [String]) async -> [UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, imageUrl) in urls.enumerated() {
                group.addTask {
                    (index, await ImageLoadingUtility.loadImageFromURL(imageUrl: imageUrl))
                }
            }
            var indexed: [(Int, UIImage)] = []
            for await (i, image) in group {
                if let image { indexed.append((i, image)) }
            }
            return indexed.sorted { $0.0 < $1.0 }.map { $0.1 }
        }
    }

    /// Reloads photos for a specific post.
    func reloadPostPhotos(for post: PlacePost) {
        loadPostPhotos(for: post)
    }

    // MARK: - Profile Photos

    /// Loads a profile photo from URL (URL comes from SQL JOIN with users table).
    func loadProfilePhotoFromURL(userId: String, photoUrl: String) {
        guard !photoUrl.isEmpty, userProfilePhotos[userId] == nil else { return }

        Task {
            guard let url = URL(string: photoUrl) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    self.userProfilePhotos[userId] = image
                    self.profilePhotoLoadingStates[userId] = .loaded
                }
            } catch {
                self.profilePhotoLoadingStates[userId] = .loaded
            }
        }
    }

    // MARK: - Public Accessors

    /// Returns loaded photos for a specific post.
    func photos(forPostId postId: String) -> [UIImage] {
        return reviewPhotos[postId] ?? []
    }

    /// Returns loading state for a specific post's photos.
    func photoLoadingState(forPostId postId: String) -> LoadingState {
        return reviewPhotoLoadingStates[postId] ?? .idle
    }

    /// Returns cached profile photo for a user.
    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId]
    }

    /// Returns loading state for a user's profile photo.
    func profilePhotoLoadingState(forUserId userId: String) -> LoadingState {
        return profilePhotoLoadingStates[userId] ?? .idle
    }
}
