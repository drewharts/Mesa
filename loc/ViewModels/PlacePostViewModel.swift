//
//  PlacePostViewModel.swift
//  loc
//
//  ViewModel for creating new posts
//

import SwiftUI
import Combine

class PlacePostViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var postText: String = ""
    @Published var images: [UIImage] = []
    @Published var wouldReturn: Bool? = nil
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private let place: DetailPlace
    private let userId: String
    private let userFirstName: String
    private let userLastName: String
    private let profilePhotoUrl: String
    private let postService: PostService
    private let imageService: ImageService
    private let placeService: PlaceService
    
    // MARK: - Init
    init(place: DetailPlace,
         userId: String,
         userFirstName: String,
         userLastName: String,
         profilePhotoUrl: String,
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
    }
    
    func submitPost(completion: @escaping (Result<PlacePost, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        let timestamp = Date()
        let postId = UUID().uuidString
        
        var post = PlacePost(
            id: postId,
            userId: userId,
            profilePhotoUrl: profilePhotoUrl,
            userFirstName: userFirstName,
            userLastName: userLastName,
            placeId: place.id.uuidString,
            placeName: place.name,
            text: postText,
            timestamp: timestamp,
            images: [],
            likes: 0,
            wouldReturn: wouldReturn
        )
        
        if !images.isEmpty {
            imageService.uploadImagesForPost(post: post, images: images) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let imageUrls):
                    post.images = imageUrls
                    self.savePost(post, completion: completion)
                case .failure(let error):
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to upload images: \(error.localizedDescription)"
                        completion(.failure(error))
                    }
                }
            }
        } else {
            savePost(post, completion: completion)
        }
    }
    
    private func savePost(_ post: PlacePost, completion: @escaping (Result<PlacePost, Error>) -> Void) {
        // Service layer handles ensuring place exists (FK constraint)
        postService.savePost(post, forPlace: place) { [weak self] result in
            DispatchQueue.main.async {
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
    
    func deletePost(postId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        isLoading = true
        errorMessage = nil
        
        postService.deletePost(postId: postId) { [weak self] result in
            DispatchQueue.main.async {
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

