//
//  DataManager.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/29/25.
//

import Foundation
import FirebaseAuth
import UIKit

//TODO:
    // include my places
    // include all places friends have reviewed
class DataManager {
    private let fireStoreService: FirestoreService
    private let userSession: UserSession
    private let locationManager: LocationManager
    private let profileViewModel: ProfileViewModel
    private let detailPlaceViewModel: DetailPlaceViewModel
    
    init(
        fireStoreService: FirestoreService,
        userSession: UserSession,
        locationManager: LocationManager,
        profileViewModel: ProfileViewModel,
        detailPlaceViewModel: DetailPlaceViewModel
    ) {
        self.fireStoreService = fireStoreService
        self.userSession = userSession
        self.locationManager = locationManager
        self.profileViewModel = profileViewModel
        self.detailPlaceViewModel = detailPlaceViewModel
    }
    
    func initializeProfileData(userId: String) {
        profileViewModel.startLoading()
        loadProfileData(userId: userId)
        loadUserFavoritePlaces(userId: userId)
        loadUserPlaceLists(userId: userId)
        loadFollowing(userId: userId)
        loadFollowers(userId: userId)
        calculateMapAnnotations()
    }
    
    func calculateMapAnnotations() {
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    // Load's current user's profile data and profile picture
    func loadProfileData(userId: String) {
        fireStoreService.fetchUserById(userId: userId) { result in
            switch result {
            case .success(let profileData):
                self.profileViewModel.user = profileData
                if let profilePhotoUrl = profileData.profilePhotoURL {
                    self.AddProfilePicture(userId: userId, profilePhotoUrl: profilePhotoUrl)
                }
                self.profileViewModel.finishLoading()
            case .failure(let error):
                print("Error loading profile data: \(error.localizedDescription)")
                self.profileViewModel.finishLoading()
            }
        }
    }

    func downloadImage(from url: URL, completion: @escaping (UIImage?) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("Error downloading image: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            DispatchQueue.main.async {
                completion(UIImage(data: data))
            }
        }.resume()
    }

    func AddProfilePicture(userId: String, profilePhotoUrl: URL) {
        downloadImage(from: profilePhotoUrl) { image in
            if let image = image {
                self.detailPlaceViewModel.userProfilePicture[userId] = image
                self.profileViewModel.userPicture = image
            } else {
                print("Failed to download profile picture from URL: \(profilePhotoUrl)")
            }
        }
    }
    
    func loadUserFavoritePlaces(userId: String, forUser: ProfileData? = nil) {
        fireStoreService.fetchProfileFavorites(userId: userId) { places in
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userFavorites = places?.map { $0.id.uuidString } ?? []
            }
            
            // Store DetailPlace objects in DetailPlaceViewModel
            if let places = places {
                for place in places {
                    let placeId = place.id.uuidString
                    self.detailPlaceViewModel.places[placeId] = place
                    // Update place savers 
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                }
            }
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        }
    }
    
    func loadUserPlaceLists(userId: String, forUser: ProfileData? = nil) {
        fireStoreService.fetchLists(userId: userId) { lists in
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userLists = lists
            }
            
            // Process places in each list
            for list in lists {
                self.processPlacesInList(list: list, userId: userId)
            }
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        }
    }

    func processPlacesInList(list: PlaceList, userId: String) {
        for place in list.places {
            let placeId = place.id.uuidString
            fireStoreService.fetchPlace(withId: placeId) { result in
                switch result {
                case .success(let detailPlace):
                    self.detailPlaceViewModel.places[placeId] = detailPlace
                    // If we have a user object, update the place savers
                    if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                        self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                    } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                        self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                    }
                case .failure(let error):
                    print("Error fetching place details: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func loadFollowing(userId: String) {
        fireStoreService.fetchFollowingProfilesData(for: userId) { profiles, error in
            if let error = error {
                print("Error loading following profiles: \(error.localizedDescription)")
                self.profileViewModel.finishLoading()
                return
            }
            
            if let profiles = profiles {
                // Store the profiles in the profileViewModel
                self.profileViewModel.userFollowing = profiles
                for profile in profiles {
                    self.loadUserFavoritePlaces(userId: profile.id, forUser: profile)
                    self.loadUserPlaceLists(userId: profile.id, forUser: profile)
                    if let profilePhotoURL = profile.profilePhotoURL {
                        self.AddProfilePicture(userId: profile.id, profilePhotoUrl: profilePhotoURL)
                    }
                }
            }
            self.profileViewModel.finishLoading()
        }
    }

    
    func loadFollowers(userId: String) {
        fireStoreService.fetchFollowerProfilesData(for: userId) { profiles, error in
            if let error = error {
                print("Error loading following profiles: \(error.localizedDescription)")
                self.profileViewModel.finishLoading()
                return
            }
            
            if let profiles = profiles {
                // Store the profiles in the profileViewModel
                self.profileViewModel.userFollowers = profiles
            }
            self.profileViewModel.finishLoading()
        }
    }
    

}

