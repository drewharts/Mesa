//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import UIKit
import SwiftUICore
import MapboxSearch

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
    
    func selectUser(_ user: ProfileData, currentUserId: String) {
        DispatchQueue.main.async {
            self.selectedUser = user
            self.isUserDetailPresented = true
            self.checkIfFollowing(currentUserId: currentUserId)
        }
        
        fetchProfileFavorites(userId: user.id)
        fetchLists(userId: user.id)
        fetchFollowers(userId: user.id)
        fetchFavoritePlaceImages()
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
            DispatchQueue.main.async { self.isFollowing = false }
            return
        }
        
        firestoreService.isFollowingUser(followerId: currentUserId, followingId: targetUserId) { [weak self] isFollowing in
            DispatchQueue.main.async {
                self?.isFollowing = isFollowing
            }
        }
    }
    
    func toggleFollowUser(currentUserId: String) {
        let targetUserId = selectedUser?.id ?? ""
        
        if isFollowing {
            firestoreService.unfollowUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isFollowing = false
                        self.followers = max(0, self.followers - 1)
                    }
                }
            }
        } else {
            firestoreService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isFollowing = true
                        self.followers += 1
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
            DispatchQueue.main.async {
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
    }
    
    func fetchFavoritePlaceImages() {
        print("Starting fetchFavoritePlaceImages for \(userFavorites.count) favorites")
        for place in userFavorites {
            fetchImage(for: place) { [weak self] placeId, image in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let image = image {
                        self.favoritePlaceImages[placeId] = image
                        // Explicitly trigger UI update
                        self.objectWillChange.send()
                        print("Updated image for place \(placeId) in favoritePlaceImages")
                    }
                }
            }
        }
    }
    
    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
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
    
    // Helper method to fetch images with completion handler
    private func fetchImage(for place: DetailPlace, completion: @escaping (String, UIImage?) -> Void) {
        let placeId = place.id.uuidString
        
        // Skip if image already exists in either dictionary
        if favoritePlaceImages[placeId] != nil || placeImages[placeId] != nil {
            completion(placeId, favoritePlaceImages[placeId] ?? placeImages[placeId])
            return
        }
        
        // When viewing someone else's profile, we want to see ALL their reviews for images,
        // not just reviews from people we follow, so we'll use the generic fetchReviews method
        firestoreService.fetchReviews(placeId: placeId, latestOnly: true) { [weak self] (reviews: [ReviewProtocol]?, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
                return
            }
            
            print("Fetched \(reviews?.count ?? 0) reviews for place \(placeId)")
            if let firstReview = reviews?.first,
               let firstPhotoURLString = firstReview.images.first,
               let url = URL(string: firstPhotoURLString) {
                print("Fetching image from URL: \(firstPhotoURLString)")
                URLSession.shared.dataTask(with: url) { data, response, error in
                    if let error = error {
                        print("Error loading image for place \(placeId): \(error.localizedDescription)")
                        DispatchQueue.main.async {
                            completion(placeId, nil)
                        }
                        return
                    }
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            completion(placeId, image)
                            print("Loaded image for place \(placeId)")
                        }
                    } else {
                        DispatchQueue.main.async {
                            completion(placeId, nil)
                            print("No image data for place \(placeId)")
                        }
                    }
                }.resume()
            } else {
                print("No valid review or image URL for place \(placeId)")
                DispatchQueue.main.async {
                    completion(placeId, nil)
                }
            }
        }
    }
}
