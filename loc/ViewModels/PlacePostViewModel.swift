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
    @Published var images: [UIImage] = []
    @Published var wouldReturn: Bool? = nil
    
    @Published var isLoading: Bool = false
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
    
    /// Whether the post can be submitted (has content)
    var canSubmit: Bool {
        !images.isEmpty || !postText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
        self.images = preselectedImages
        self.postService = postService
        self.imageService = imageService
        self.placeService = placeService
    }
    
    // MARK: - Image Management
    
    func addImages(_ newImages: [UIImage]) {
        images.append(contentsOf: newImages)
    }
    
    func removeImage(at index: Int) {
        guard index >= 0 && index < images.count else { return }
        images.remove(at: index)
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
    
    func submitPost(completion: @escaping (Result<PlacePost, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        var post = createPost()
        
        if !images.isEmpty {
            uploadImagesAndSavePost(&post, completion: completion)
        } else {
            savePost(post, completion: completion)
        }
    }
    
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
    
    private func uploadImagesAndSavePost(_ post: inout PlacePost, completion: @escaping (Result<PlacePost, Error>) -> Void) {
        var mutablePost = post
        imageService.uploadImagesForPost(post: mutablePost, images: images) { [weak self] result in
            guard let self = self else { return }
            
            Task { @MainActor in
                switch result {
                case .success(let imageUrls):
                    mutablePost.images = imageUrls
                    self.savePost(mutablePost, completion: completion)
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = "Failed to upload images: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func savePost(_ post: PlacePost, completion: @escaping (Result<PlacePost, Error>) -> Void) {
        postService.savePost(post, forPlace: place) { [weak self] result in
            Task { @MainActor in
                self?.isLoading = false
                switch result {
                case .success:
                    self?.addPhotosToPlace(from: post)
                    completion(.success(post))
                case .failure(let error):
                    self?.errorMessage = "Failed to save post: \(error.localizedDescription)"
                    completion(.failure(error))
                }
            }
        }
    }
    
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

