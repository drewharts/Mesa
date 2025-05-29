//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import UIKit
import SwiftUICore
import MapboxSearch

@MainActor
class UserProfileViewModel: ObservableObject {
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    @Published var userFavorites: [DetailPlace] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]

    @Published var userLists: [PlaceList] = []
    @Published var placeListMapboxPlaces: [UUID: [DetailPlace]] = [:]
    @Published var placeImages: [String: UIImage] = [:]
    @Published var isFollowing: Bool = false
    @Published var followers: Int = 0
    private let firestoreService = FirestoreService()
    private let mapboxSearchService = MapboxSearchService()
    private let dataManager: DataManager
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    init(dataManager: DataManager, detailPlaceViewModel: DetailPlaceViewModel) {
        self.dataManager = dataManager
        self.detailPlaceViewModel = detailPlaceViewModel
    }
    
    func selectUser(_ user: ProfileData, currentUserId: String) {
        self.selectedUser = user
        self.isUserDetailPresented = true
        self.checkIfFollowing(currentUserId: currentUserId)
        self.fetchProfileFavorites(userId: user.id)
        self.fetchLists(userId: user.id)
        self.fetchFollowers(userId: user.id)
        self.fetchFavoritePlaceImages()
    }
    
    func fetchFollowers(userId: String) {
        firestoreService.getNumberFollowers(forUserId: userId) { (count, error) in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                return
            }
            self.followers = count
        }
    }
    
    func checkIfFollowing(currentUserId: String) {
        guard let targetUserId = selectedUser?.id, !targetUserId.isEmpty else {
            self.isFollowing = false
            return
        }
        firestoreService.isFollowingUser(followerId: currentUserId, followingId: targetUserId) { [weak self] isFollowing in
            self?.isFollowing = isFollowing
        }
    }
    
    func toggleFollowUser(currentUserId: String) {
        guard let targetUserId = selectedUser?.id else { return }
        if isFollowing {
            firestoreService.unfollowUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    self.isFollowing = false
                    self.followers = max(0, self.followers - 1)
                    // Remove user from placeSavers and recalculate annotations
                    self.removeUserFromPlaceSavers(userId: targetUserId)
                    self.detailPlaceViewModel.calculateAnnotationPlaces()
                }
            }
        } else {
            firestoreService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    self.isFollowing = true
                    self.followers += 1
                    // Load new user's places and recalculate annotations
                    Task {
                        await self.dataManager.loadUserFavoritePlaces(userId: targetUserId, forUser: self.selectedUser)
                        await self.dataManager.loadUserPlaceLists(userId: targetUserId, forUser: self.selectedUser)
                        self.detailPlaceViewModel.calculateAnnotationPlaces()
                    }
                }
            }
        }
    }
    
    func followUser(currentUserId: String, targetUserId: String) {
        firestoreService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
            if let error = error {
                print("Error following user: \(error.localizedDescription)")
            } else if success {
                print("Successfully followed user \(targetUserId).")
            }
        }
    }
    
    private func fetchProfileFavorites(userId: String) {
        print("Fetching favorites for userId: \(userId)")
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] favorites in
            guard let self = self else { return }
            if favorites == nil {
                print("Favorites fetch returned nil - possible error or no data")
                self.userFavorites = []
            } else if favorites!.isEmpty {
                print("No favorites found for userId: \(userId)")
                self.userFavorites = []
            } else {
                print("Fetched \(favorites!.count) favorites for userId: \(userId)")
                self.userFavorites = favorites!
            }
        }
    }
    
    func fetchFavoritePlaceImages() {
        print("Starting fetchFavoritePlaceImages for \(userFavorites.count) favorites")
        for place in userFavorites {
            fetchImage(for: place) { [weak self] placeId, image in
                guard let self = self else { return }
                if let image = image {
                    self.favoritePlaceImages[placeId] = image
                    // Explicitly trigger UI update
                    self.objectWillChange.send()
                    print("Updated image for place \(placeId) in favoritePlaceImages")
                }
            }
        }
    }
    
    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            self.userLists = lists
            // Fetch places and images for each PlaceList
            for list in lists {
                self.fetchFirestorePlaces(for: list.places) { places in
                    self.placeListMapboxPlaces[list.id] = places
                    // Fetch images for places in this list
                    for place in places {
                        self.fetchImage(for: place) { [weak self] placeId, image in
                            self?.placeImages[placeId] = image
                        }
                    }
                }
            }
        }
    }
    
    func fetchFirestorePlaces(for places: [Place], completion: @escaping ([DetailPlace]) -> Void) {
        var fetchedPlaces: [DetailPlace] = []
        let dispatchGroup = DispatchGroup()
        
        for place in places {
            dispatchGroup.enter()
            
            let documentId = place.id.uuidString
            
            firestoreService.fetchPlace(withId: documentId) { result in
                switch result {
                case .success(let detailPlace):
                    fetchedPlaces.append(detailPlace)
                case .failure(let error):
                    print("Error fetching place from Firestore: \(error.localizedDescription)")
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async {
                completion(fetchedPlaces)
            }
        }
    }
    
    private func downloadFirstSuccessfulImage(from urls: [URL], for placeId: String, completion: @escaping (UIImage?) -> Void) {
        let group = DispatchGroup()
        var downloadedImage: UIImage?
        
        print("Attempting to download image for place \(placeId) from \(urls.count) URLs")
        
        for url in urls {
            group.enter()
            print("Trying URL: \(url.absoluteString)")
            
            URLSession.shared.dataTask(with: url) { data, response, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error downloading image from \(url.absoluteString): \(error.localizedDescription)")
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    print("Successfully downloaded image from \(url.absoluteString)")
                    downloadedImage = image
                } else {
                    print("Failed to create image from data for URL: \(url.absoluteString)")
                }
            }.resume()
            
            // If we got an image, we can stop trying other URLs
            if downloadedImage != nil {
                break
            }
        }
        
        group.notify(queue: .main) {
            if let image = downloadedImage {
                print("Successfully cached image for place \(placeId)")
                self.placeImages[placeId] = image
            } else {
                print("Failed to download any image for place \(placeId)")
            }
            completion(downloadedImage)
        }
    }
    
    // Helper method to fetch images with completion handler
    private func fetchImage(for place: DetailPlace, completion: @escaping (String, UIImage?) -> Void) {
        let placeId = place.id.uuidString
        print("Starting image fetch for place: \(place.name) (\(placeId))")
        
        // Skip if image already exists in either dictionary
        if favoritePlaceImages[placeId] != nil || placeImages[placeId] != nil {
            print("Image already cached for place \(placeId)")
            completion(placeId, favoritePlaceImages[placeId] ?? placeImages[placeId])
            return
        }
        
        // Fetch reviews for this place
        firestoreService.fetchReviews(placeId: placeId, latestOnly: false) { [weak self] (reviews: [ReviewProtocol]?, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
                return
            }
            
            print("Found \(reviews?.count ?? 0) reviews for place \(placeId)")
            
            // Collect all image URLs from all reviews
            var imageURLs: [URL] = []
            for review in reviews ?? [] {
                for urlString in review.images {
                    if let url = URL(string: urlString) {
                        imageURLs.append(url)
                    }
                }
            }
            
            print("Found \(imageURLs.count) image URLs for place \(placeId)")
            
            if !imageURLs.isEmpty {
                self.downloadFirstSuccessfulImage(from: imageURLs, for: placeId) { image in
                    DispatchQueue.main.async {
                        completion(placeId, image)
                    }
                }
            } else {
                print("No image URLs found for place \(placeId)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
            }
        }
    }
    
    func downloadImage(from url: URL) async throws -> UIImage {
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let image = UIImage(data: data) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"])
        }
        return image
    }
    
    // Helper to remove a user from all placeSavers
    private func removeUserFromPlaceSavers(userId: String) {
        for (placeId, savers) in detailPlaceViewModel.placeSavers {
            detailPlaceViewModel.placeSavers[placeId] = savers.filter { $0 != userId }
            // Optionally, remove the place if no savers left:
            // if detailPlaceViewModel.placeSavers[placeId]?.isEmpty == true {
            //     detailPlaceViewModel.places.removeValue(forKey: placeId)
            // }
        }
    }
}
