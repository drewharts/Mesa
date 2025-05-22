//
//  DataManager.swift
//  loc
//
//  Created by Andrew Hartsfield II on 4/29/25.
//

import Foundation
import FirebaseAuth
import UIKit

@MainActor
class DataManager: ObservableObject {
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
    
    func initializeProfileData(userId: String) async {
        profileViewModel.startLoading()
        await loadProfileData(userId: userId)
        await fetchFollowerAndFollowingCountsAsync(userId: userId)
        await loadUserFavoritePlaces(userId: userId)
        await loadUserPlaceLists(userId: userId)
        await loadUserMyPlaces(userId: userId)
        await loadFollowing(userId: userId)
        await loadFollowers(userId: userId)
        await loadReviewedPlacesForUserAndFollowing(userId: userId)
        calculateMapAnnotations()
    }
    
    func calculateMapAnnotations() {
        detailPlaceViewModel.calculateAnnotationPlaces()
    }
    
    func loadUserMyPlaces(userId: String) async {
        do {
            let places = try await fireStoreService.fetchMyPlaces(userId: userId)
            for place in places {
                self.profileViewModel.myPlaces.append(place.id.uuidString)
                self.detailPlaceViewModel.places[place.id.uuidString] = place
                self.detailPlaceViewModel.fetchPlaceImage(for: place.id.uuidString)
                // Add the current user as a saver for their own place
                let placeId = place.id.uuidString
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            }
        } catch {
            print("Error loading my places: \(error.localizedDescription)")
        }
    }
    
    // Load's current user's profile data and profile picture
    func loadProfileData(userId: String) async {
        do {
            let profileData = try await fireStoreService.fetchUserById(userId: userId)
            self.profileViewModel.user = profileData
            if let profilePhotoUrl = profileData.profilePhotoURL {
                self.AddProfilePicture(userId: userId, profilePhotoUrl: profilePhotoUrl, isCurrentUser: true)
            }
            self.profileViewModel.finishLoading()
        } catch {
            print("Error loading profile data: \(error.localizedDescription)")
            self.profileViewModel.finishLoading()
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

    func AddProfilePicture(userId: String, profilePhotoUrl: URL, isCurrentUser: Bool = false) {
        downloadImage(from: profilePhotoUrl) { image in
            if let image = image {
                if isCurrentUser {
                    self.profileViewModel.userPicture = image
                }
                self.detailPlaceViewModel.userProfilePicture[userId] = image
                self.detailPlaceViewModel.calculateAnnotationPlaces()
            } else {
                print("Failed to download profile picture from URL: \(profilePhotoUrl)")
            }
        }
    }
    
    func loadUserFavoritePlaces(userId: String, forUser: ProfileData? = nil) async {
        do {
            let places = try await fireStoreService.fetchProfileFavorites(userId: userId)
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userFavorites = places.map { $0.id.uuidString }
            }
            // Store DetailPlace objects in DetailPlaceViewModel
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
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        } catch {
            print("Error loading favorite places: \(error.localizedDescription)")
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        }
    }
    
    func loadUserPlaceLists(userId: String, forUser: ProfileData? = nil) async {
        do {
            let lists = try await fireStoreService.fetchLists(userId: userId)
            // If this is for the current user, update the ProfileViewModel
            if forUser == nil {
                self.profileViewModel.userLists = lists
                self.profileViewModel.userListsPlaces = lists.reduce(into: [String: [String]]()) { result, list in
                    result[list.id.uuidString] = list.places.map { $0.id.uuidString }
                }
            }
            // Process places in each list
            for list in lists {
                await self.processPlacesInList(list: list, userId: userId)
            }
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        } catch {
            print("Error loading user place lists: \(error.localizedDescription)")
            if forUser == nil {
                self.profileViewModel.finishLoading()
            }
        }
    }

    func processPlacesInList(list: PlaceList, userId: String) async {
        for place in list.places {
            let placeId = place.id.uuidString
            do {
                let detailPlace = try await fireStoreService.fetchPlace(withId: placeId)
                self.detailPlaceViewModel.places[placeId] = detailPlace
                // If we have a user object, update the place savers
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
            } catch {
                print("Error fetching place details: \(error.localizedDescription)")
            }
        }
    }
    
    func loadFollowing(userId: String) async {
        do {
            let profiles = try await fireStoreService.fetchFollowingProfilesData(for: userId)
            // Store the profiles in the profileViewModel
            self.profileViewModel.userFollowing = profiles
            for profile in profiles {
                await self.loadUserFavoritePlaces(userId: profile.id, forUser: profile)
                await self.loadUserPlaceLists(userId: profile.id, forUser: profile)
                if let profilePhotoURL = profile.profilePhotoURL {
                    self.AddProfilePicture(userId: profile.id, profilePhotoUrl: profilePhotoURL)
                }
            }
            self.profileViewModel.finishLoading()
        } catch {
            print("Error loading following profiles: \(error.localizedDescription)")
            self.profileViewModel.finishLoading()
        }
    }

    
    func loadFollowers(userId: String) async {
        do {
            let profiles = try await fireStoreService.fetchFollowerProfilesData(for: userId)
            // Store the profiles in the profileViewModel
            self.profileViewModel.userFollowers = profiles
            self.profileViewModel.finishLoading()
        } catch {
            print("Error loading followers: \(error.localizedDescription)")
            self.profileViewModel.finishLoading()
        }
    }
    
    func fetchFollowerAndFollowingCountsAsync(userId: String) async {
        async let followers: Int = try! await fireStoreService.getNumberFollowers(forUserId: userId)
        async let following: Int = try! await fireStoreService.getNumberFollowing(forUserId: userId)
        let (followersCount, followingCount) = await (followers, following)
        profileViewModel.followersCount = followersCount
        profileViewModel.followingCount = followingCount
    }
    
    // Loads all places the user has reviewed, even if not in favorites or lists
    func loadUserReviewedPlaces(userId: String) async {
        do {
            // Fetch all reviews (RestaurantReview and GenericReview)
            let restaurantReviews: [RestaurantReview] = try await fireStoreService.fetchUserReviews(userId: userId)
            let genericReviews: [GenericReview] = try await fireStoreService.fetchUserReviews(userId: userId)
            let allReviews: [ReviewProtocol] = restaurantReviews + genericReviews
            
            for review in allReviews {
                let placeId = review.placeId
                // Add userId to placeSavers if not already present
                if self.detailPlaceViewModel.placeSavers[placeId] == nil {
                    self.detailPlaceViewModel.placeSavers[placeId] = [userId]
                } else if !self.detailPlaceViewModel.placeSavers[placeId]!.contains(userId) {
                    self.detailPlaceViewModel.placeSavers[placeId]!.append(userId)
                }
                // Fetch and store the place if not already present
                if self.detailPlaceViewModel.places[placeId] == nil {
                    do {
                        let detailPlace = try await fireStoreService.fetchPlace(withId: placeId)
                        self.detailPlaceViewModel.places[placeId] = detailPlace
                        self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    } catch {
                        print("Error fetching place for reviewed placeId \(placeId): \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("Error loading user reviewed places: \(error.localizedDescription)")
        }
    }
    
    // Loads all reviewed places for the current user and their following
    func loadReviewedPlacesForUserAndFollowing(userId: String) async {
        let followingIds = profileViewModel.userFollowing.map { $0.id }
        let allUserIds = followingIds + [userId]
        for uid in allUserIds {
            await loadUserReviewedPlaces(userId: uid)
        }
    }
}

