//
//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import GooglePlaces
import UIKit
import SwiftUICore

class UserProfileViewModel: ObservableObject {
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    @Published var userFavorites: [GMSPlace] = []
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [GMSPlace]] = [:] // Store places per list
    @Published var placeImages: [String: UIImage] = [:] // Store images by placeID
    @Published var isFollowing: Bool = false  // ✅ Track follow state
    
    private let firestoreService = FirestoreService()
    private let googlePlacesService = GooglePlacesService()
    
    
    func selectUser(_ user: ProfileData, currentUserId: String) {
        DispatchQueue.main.async {
            self.selectedUser = user
            self.isUserDetailPresented = true
            self.checkIfFollowing(currentUserId: currentUserId)
        }
        
        fetchProfileFavorites(userId: user.id)
        fetchLists(userId: user.id)
    }
    
    func checkIfFollowing(currentUserId: String) {
        // Ensure that selectedUser is set and has a valid id
        guard let targetUserId = selectedUser?.id, !targetUserId.isEmpty else {
            DispatchQueue.main.async { self.isFollowing = false }
            return
        }
        
        // Call the firestore service to check the following status.
        firestoreService.isFollowingUser(followerId: currentUserId, followingId: targetUserId) { [weak self] isFollowing in
            // Always update UI state on the main thread.
            DispatchQueue.main.async {
                self?.isFollowing = isFollowing
            }
        }
    }
    
    /// Follows or unfollows the selected user.
    func toggleFollowUser(currentUserId: String) {
              let targetUserId = selectedUser?.id ?? ""


        if isFollowing {
            firestoreService.unfollowUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isFollowing = false
                    }
                }
            }
        } else {
            firestoreService.followUser(followerId: currentUserId, followingId: targetUserId) { success, error in
                if success {
                    DispatchQueue.main.async {
                        self.isFollowing = true
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
        firestoreService.fetchProfileFavorites(userId: userId) { places in
            DispatchQueue.main.async {
                if places.isEmpty {
                    print("No favorite places found.")
                    self.userFavorites = []
                } else {
                    self.fetchGMSPlaces(for: places) { gmsPlaces in
                        self.userFavorites = gmsPlaces
                    }
                }
            }
        }
    }

    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
                self.userLists = lists
                
                // Fetch GMSPlaces for each PlaceList
                for list in lists {
                    self.fetchGMSPlaces(for: list.places) { gmsPlaces in
                        self.placeListGMSPlaces[list.id] = gmsPlaces
                    }
                }
            }
        }
    }

    private func fetchGMSPlaces(for places: [Place], completion: @escaping ([GMSPlace]) -> Void) {
        var fetchedPlaces: [GMSPlace] = []
        let dispatchGroup = DispatchGroup()

        for place in places {
            dispatchGroup.enter()
            googlePlacesService.fetchPlace(placeID: place.id) { gmsPlace, error in
                if let gmsPlace = gmsPlace {
                    fetchedPlaces.append(gmsPlace)
                    self.fetchPhoto(for: gmsPlace) // Fetch photo after getting GMSPlace
                } else if let error = error {
                    print("Error fetching GMSPlace: \(error.localizedDescription)")
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
    
    /// Fetches a photo for a given `GMSPlace` and stores it in `placeImages`
    private func fetchPhoto(for place: GMSPlace) {
        guard let placeID = place.placeID else { return }
        if placeImages[placeID] != nil { return } // Avoid redundant fetching
        
        googlePlacesService.fetchPhoto(placeID: placeID) { image in
            DispatchQueue.main.async {
                self.placeImages[placeID] = image
            }
        }
    }
}
