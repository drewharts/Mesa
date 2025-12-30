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
    
    // MARK: - Nearby Photos Management
    
    func loadNearbyPhotos() {
        guard let coordinate = place.coordinate else { return }
        
        isLoadingNearbyPhotos = true
        nearbyPhotos = [] // Clear previous results
        
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            guard let self = self else { return }
            
            if status == .authorized || status == .limited {
                self.filterPhotosByLocation(coordinate: coordinate)
            } else {
                Task { @MainActor in
                    self.isLoadingNearbyPhotos = false
                }
            }
        }
    }
    
    private func filterPhotosByLocation(coordinate: CLLocationCoordinate2D) {
        let restaurantLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        let maxDistance: CLLocationDistance = 500 // meters
        let maxResults = 20
        
        // Narrow search to recent photos first (last 2 years)
        let twoYearsAgo = Date().addingTimeInterval(-2 * 365 * 24 * 60 * 60)
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@",
            PHAssetMediaType.image.rawValue,
            twoYearsAgo as NSDate
        )
        
        // Move heavy processing to background queue
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let recentPhotos = PHAsset.fetchAssets(with: fetchOptions)
            var nearby: [PHAsset] = []
            let batchSize = 100 // Process in batches
            var processedCount = 0
            
            // First pass: Check recent photos (last 2 years)
            recentPhotos.enumerateObjects(options: []) { asset, index, stop in
                guard let location = asset.location else { return }
                
                let distance = restaurantLocation.distance(from: location)
                if distance <= maxDistance {
                    nearby.append(asset)
                    
                    // Update UI incrementally (every 5 found or when we have enough)
                    if nearby.count % 5 == 0 || nearby.count >= maxResults {
                        DispatchQueue.main.async {
                            self.nearbyPhotos = Array(nearby.prefix(maxResults))
                        }
                    }
                }
                
                // Stop if we found enough
                if nearby.count >= maxResults {
                    stop.pointee = true
                    return
                }
                
                processedCount = index + 1
            }
            
            // If we didn't find enough in recent photos, check older photos
            if nearby.count < maxResults {
                let allPhotosOptions = PHFetchOptions()
                allPhotosOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                allPhotosOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
                
                let allPhotos = PHAsset.fetchAssets(with: allPhotosOptions)
                let maxPhotosToCheck = min(100_000, allPhotos.count)
                
                allPhotos.enumerateObjects(options: []) { asset, index, stop in
                    // Skip photos we already checked
                    if index < processedCount {
                        return
                    }
                    
                    // Stop if we've checked enough or found enough
                    if index >= maxPhotosToCheck || nearby.count >= maxResults {
                        stop.pointee = true
                        return
                    }
                    
                    guard let location = asset.location else { return }
                    
                    let distance = restaurantLocation.distance(from: location)
                    if distance <= maxDistance {
                        nearby.append(asset)
                        
                        // Update UI incrementally
                        DispatchQueue.main.async {
                            self.nearbyPhotos = Array(nearby.prefix(maxResults))
                        }
                        
                        if nearby.count >= maxResults {
                            stop.pointee = true
                            return
                        }
                    }
                }
            }
            
            // Final update on main thread
            DispatchQueue.main.async {
                self.nearbyPhotos = Array(nearby.prefix(maxResults))
                self.isLoadingNearbyPhotos = false
            }
        }
    }
    
    func addPhotoFromAsset(_ asset: PHAsset) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] image, _ in
            if let image = image {
                Task { @MainActor in
                    self?.images.append(image)
                }
            }
        }
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

