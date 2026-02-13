//
//  PlacePostViewModel.swift
//  loc
//
//  ViewModel for creating new posts
//

import SwiftUI
import Combine

@MainActor
class PlacePostViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var postText: String = ""
    @Published var selectedMedia: [SelectedMediaItem] = []
    @Published var wouldReturn: Bool? = nil

    @Published var isLoading: Bool = false
    @Published var uploadProgress: Double = 0.0
    @Published var errorMessage: String?
    
    // MARK: - UI State (owned by ViewModel for testability)
    @Published var showCaptionSection: Bool = false
    @Published var showSentimentSection: Bool = false
    
    // MARK: - Exposed Properties
    let place: DetailPlace
    
    // MARK: - Private Properties
    private let userId: String
    private let userFirstName: String
    private let userLastName: String
    private let profilePhotoUrl: String
    private let postService: PostService
    private let imageService: ImageService
    private let placeService: PlaceService
    
    // MARK: - Computed Properties
    
    /// Whether the post can be submitted (has content).
    var canSubmit: Bool {
        !selectedMedia.isEmpty || !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns only the image items from selected media.
    private var selectedImages: [UIImage] {
        selectedMedia.compactMap { $0.type == .image ? $0.image : nil }
    }

    /// Returns only the video local URLs from selected media.
    private var selectedVideoURLs: [URL] {
        selectedMedia.compactMap { $0.type == .video ? $0.videoURL : nil }
    }
    
    /// Whether to show the caption add button
    var shouldShowCaptionButton: Bool {
        !showCaptionSection && postText.isEmpty
    }
    
    /// Whether to show the sentiment add button
    var shouldShowSentimentButton: Bool {
        !showSentimentSection && wouldReturn == nil
    }
    
    // MARK: - Init
    init(place: DetailPlace,
         userId: String,
         userFirstName: String,
         userLastName: String,
         profilePhotoUrl: String,
         preselectedImages: [UIImage] = [],
         postService: PostService = .shared,
         imageService: ImageService = .shared,
         placeService: PlaceService = .shared) {
        self.place = place
        self.userId = userId
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.profilePhotoUrl = profilePhotoUrl
        self.postService = postService
        self.imageService = imageService
        self.placeService = placeService

        // Convert preselected images to SelectedMediaItems
        self.selectedMedia = preselectedImages.map { image in
            SelectedMediaItem(type: .image, image: image, videoURL: nil, thumbnail: nil, duration: nil)
        }
    }

    // MARK: - Media Management

    /// Removes a media item at the given index.
    func removeMedia(at index: Int) {
        guard index >= 0 && index < selectedMedia.count else { return }
        selectedMedia.remove(at: index)
    }
    
    // MARK: - Section Management
    
    func showCaption() {
        showCaptionSection = true
    }
    
    func hideCaption() {
        postText = ""
        showCaptionSection = false
    }
    
    func showSentiment() {
        showSentimentSection = true
    }
    
    func hideSentiment() {
        wouldReturn = nil
        showSentimentSection = false
    }
    
    func toggleWouldReturn(_ value: Bool) {
        wouldReturn = wouldReturn == value ? nil : value
    }
    
    // MARK: - Post Submission

    /// Submits the post by uploading all media then saving to the database.
    func submitPost(completion: @escaping (Result<PlacePost, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        uploadProgress = 0.0

        Task {
            do {
                var post = createPost()
                try await uploadMedia(for: &post)
                try await savePostAsync(post)
                addPhotosToPlace(from: post)
                completion(.success(post))
            } catch {
                errorMessage = "Failed to create post: \(error.localizedDescription)"
                completion(.failure(error))
            }
            isLoading = false
        }
    }

    /// Creates an empty PlacePost with no media URLs yet.
    private func createPost() -> PlacePost {
        PlacePost(
            id: UUID().uuidString,
            userId: userId,
            profilePhotoUrl: profilePhotoUrl,
            userFirstName: userFirstName,
            userLastName: userLastName,
            placeId: place.id.uuidString,
            placeName: place.name,
            text: postText,
            timestamp: Date(),
            images: [],
            likes: 0,
            wouldReturn: wouldReturn
        )
    }

    /// Uploads images and videos, then updates the post with resulting URLs.
    private func uploadMedia(for post: inout PlacePost) async throws {
        let images = selectedImages
        let videoURLs = selectedVideoURLs
        let totalItems = Double(images.count + videoURLs.count)
        guard totalItems > 0 else { return }

        var uploadedCount = 0.0

        // Upload images
        if !images.isEmpty {
            let imageUrls = try await imageService.uploadImagesForPostAsync(
                post: post,
                images: images
            )
            post.images = imageUrls
            uploadedCount += Double(images.count)
            uploadProgress = uploadedCount / totalItems
        }

        // Upload videos
        if !videoURLs.isEmpty {
            let videoResults = try await imageService.uploadVideosForPostAsync(
                post: post,
                videoURLs: videoURLs
            )
            post.videoUrls = videoResults.map { $0.videoURL }
            post.videoThumbnailUrls = videoResults.map { $0.thumbnailURL }
            uploadedCount += Double(videoURLs.count)
            uploadProgress = uploadedCount / totalItems
        }
    }

    /// Saves the post to the database via PostService.
    private func savePostAsync(_ post: PlacePost) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            postService.savePost(post, forPlace: place) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Adds photo URLs from the post to the place's photo collection.
    private func addPhotosToPlace(from post: PlacePost) {
        guard !post.images.isEmpty else { return }

        placeService.addPhotosToPlace(placeId: post.placeId, photoURLs: post.images) { error in
            if let error = error {
                print("Failed to add photos to place: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Post Deletion
    
    func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        postService.deletePost(postId: postId) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                
                switch result {
                case .success:
                    completion(.success(()))
                case .failure(let error):
                    self?.errorMessage = "Failed to delete post: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
}

