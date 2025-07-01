//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import MapboxSearch
import Foundation
import FirebaseFirestore
import UIKit
import CoreLocation

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: ProfileData? 
    @Published var userPicture: UIImage?
    @Published var userLists: [PlaceList] = []
    @Published var userListsPlaces: [String: [String]] = [:] // [listId: [placeId]]
    @Published var userFavorites: [String] = []
    @Published var userFollowing: [ProfileData] = []
    @Published var userFollowers: [ProfileData] = []
    //TODO: Implement my places
    @Published var myPlaces: [String] = []
    
     private let userService: UserService
    private let imageService: ImageService
    private let placeService: PlaceService
    private let reviewService: ReviewService
     internal let detailPlaceViewModel: DetailPlaceViewModel
     private let userSession: UserSession
     @Published var showMaxFavoritesAlert: Bool = false
     @Published var isLoading: Bool = true
     private var loadingTasks: Int = 0
     @Published var followersCount: Int = 0
     @Published var followingCount: Int = 0
    
    // Separate loading states for counts
    @Published var isFollowersLoading: Bool = true
    @Published var isFollowingLoading: Bool = true
    @Published var isMyPlacesLoading: Bool = true
    // Popup list loading states
    @Published var isFollowersListLoading: Bool = false
    @Published var isFollowingListLoading: Bool = false
    
    // Pagination for reviewed places
    @Published var isLoadingReviewedPlaces: Bool = false
    @Published var isLoadingMoreReviews: Bool = false
    private var _hasMoreReviews: Bool = true
    private var currentReviewPage: Int = 0
    private let reviewsPerPage: Int = 8
    private var allReviewedPlaceIds: [String] = []
    private var loadedReviewedPlaceIds: [String] = []
    
    // Location manager for distance calculations
    private let locationManager: LocationManager
    private var cancellables = Set<AnyCancellable>()
    
    init(userSession: UserSession, userService: UserService, detailPlaceViewModel: DetailPlaceViewModel, imageService: ImageService, placeService: PlaceService, reviewService: ReviewService, locationManager: LocationManager) {
         self.userService = userService
         self.detailPlaceViewModel = detailPlaceViewModel
        self.userSession = userSession
        self.imageService = imageService
        self.placeService = placeService
        self.reviewService = reviewService
        self.locationManager = locationManager
        
        // Observe location changes using Combine
        setupLocationObserver()
     }
    
    private func setupLocationObserver() {
        // Location observer removed - lists are sorted once on app startup
        // and then only when lists are modified (add/remove lists or places)
        // No need to re-sort on every location change
    }
    
     func changeProfilePhoto(_ newImage: UIImage) async {
        guard let userId = user?.id else { return }
        let croppedImage = cropToSquare(newImage)
        do {
            let url = try await imageService.updateProfilePhoto(userId: userId, image: croppedImage)
            // Update local user and userPicture
            DispatchQueue.main.async {
                self.user?.profilePhotoURL = url
                self.userPicture = croppedImage
            }
        } catch {
            print("Failed to update profile photo: \(error)")
        }
    }
    
     private func cropToSquare(_ image: UIImage) -> UIImage {
         let cgImage = image.cgImage!
         let contextImage = UIImage(cgImage: cgImage)
         let contextSize = contextImage.size
        
         // Get the size of the square
         let size = min(contextSize.width, contextSize.height)
        
         // Calculate the crop rect
         let x = (contextSize.width - size) / 2
         let y = (contextSize.height - size) / 2
         let cropRect = CGRect(x: x * image.scale,
                             y: y * image.scale,
                             width: size * image.scale,
                             height: size * image.scale)
        
         // Create the cropped image
         if let croppedCGImage = cgImage.cropping(to: cropRect) {
             return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
         }
        
         return image
     }
    
     func toggleFollowUser(userId: String) {
        guard let currentUserId = user?.id else { return }
        if userFollowing.contains(where: { $0.id == userId }) {
            // Unfollow
            userService.unfollowUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    self?.userFollowing.removeAll { $0.id == userId }
                    self?.followingCount = max(0, (self?.followingCount ?? 1) - 1)
                }
            }
        } else {
            // Follow
            userService.followUser(followerId: currentUserId, followingId: userId) { [weak self] success, error in
                if success {
                    // Fetch the ProfileData for the followed user and add to userFollowing
                    self?.userService.fetchUserById(userId: userId) { result in
                        if case .success(let profileData) = result {
                            self?.userFollowing.append(profileData)
                        }
                        self?.followingCount += 1
                    }
                }
            }
        }
    }
    
     private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
         let totalSize = CGSize(width: 80, height: 40)
         let singleCircleSize = CGSize(width: 40, height: 40)
         let renderer = UIGraphicsImageRenderer(size: totalSize)
        
         return renderer.image { context in
             let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let secondRect = CGRect(x: 15, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
             let thirdRect = CGRect(x: 30, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            
             func drawCircularImage(_ image: UIImage?, in rect: CGRect) {
                 guard let image = image else { return }
                 context.cgContext.saveGState()
                 let circlePath = UIBezierPath(ovalIn: rect)
                 circlePath.addClip()
                 image.draw(in: rect)
                 context.cgContext.setStrokeColor(UIColor.white.cgColor)
                 context.cgContext.setLineWidth(1.0)
                 context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5))
                 context.cgContext.restoreGState()
             }
            
             if image3 != nil { drawCircularImage(image3, in: thirdRect) }
             if image2 != nil { drawCircularImage(image2, in: secondRect) }
             if image1 != nil { drawCircularImage(image1, in: firstRect) }
         }
     }
    
     func isPlaceInList(listId: UUID, placeId: String) -> Bool {
         return false
     }
    
     func addPlaceToList(listId: UUID, place: DetailPlace) {
        let listIdString = listId.uuidString
        guard let userId = userSession.currentUserId else { return }
        // Find the list in userLists
        guard let listIndex = userLists.firstIndex(where: { $0.id == listId }) else { return }
        // Convert DetailPlace to Place for FirestoreService
        let placeForList = Place(id: place.id, name: place.name, address: place.address ?? "")
        // Update local userListsPlaces
        var places = userListsPlaces[listIdString] ?? []
        if !places.contains(place.id.uuidString) {
            places.append(place.id.uuidString)
            userListsPlaces[listIdString] = places
        }
        // Update the places array in the PlaceList
        if !userLists[listIndex].places.contains(where: { $0.id == place.id }) {
            userLists[listIndex].places.append(placeForList)
        }
        // Persist to Firestore
        placeService.addPlaceToList(userId: userId, listName: listIdString, place: placeForList)
        // Update DetailPlaceViewModel's places dictionary for immediate UI update
        if detailPlaceViewModel.places[place.id.uuidString] == nil {
            detailPlaceViewModel.places[place.id.uuidString] = place
        }
        // Skip sorting for individual place additions to avoid frequent re-sorting
    }
    
     func removePlaceFromList(listId: UUID, place: DetailPlace) {
         let listIdString = listId.uuidString
         guard
             var places = userListsPlaces[listIdString],
             let index = places.firstIndex(of: place.id.uuidString),
             let userId = userSession.currentUserId,
             let list = userLists.first(where: { $0.id == listId })
         else {
             return
         }

         places.remove(at: index)
         userListsPlaces[listIdString] = places
         
         let placeForList = Place(id: place.id, name: place.name, address: place.address ?? "")

         placeService.removePlaceFromList(userId: userId, listId: list.id, place: placeForList)
         
         // Skip sorting for individual place removals to avoid frequent re-sorting
     }
    
     func addFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else { return }
        // Prevent duplicates and enforce max 4 favorites
        if userFavorites.count >= 4 {
            showMaxFavoritesAlert = true
            return
        }
        if !userFavorites.contains(place.id.uuidString) {
            userFavorites.append(place.id.uuidString)
            userService.addProfileFavorite(userId: userId, place: place)
        }
    }
    
    func removeFavoritePlace(place: DetailPlace) {
        guard let userId = userSession.currentUserId else { return }
        if let index = userFavorites.firstIndex(of: place.id.uuidString) {
            userFavorites.remove(at: index)
            userService.removeProfileFavorite(userId: userId, placeId: place.id.uuidString)
        }
    }
    
    func isPlaceFavorite(placeId: String) -> Bool {
        return userFavorites.contains(placeId)
    }
    
     func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
         let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
         userLists.append(newPlaceList)
         sortListsByDistance() // Sort lists by distance after adding new list
         guard let userId = user?.id else { return }
         placeService.createNewList(placeList: newPlaceList, userID: userId)
     }
    
     func removePlaceList(placeList: PlaceList) {
         if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
             userLists.remove(at: index)
             sortListsByDistance() // Sort lists by distance after removing list
             guard let currentUserId = userSession.currentUserId else { return }
             placeService.deleteList(userId: currentUserId, listId: placeList.id.uuidString) { error in
                 if error != nil {
                     // Re-add the list if deletion failed
                     self.userLists.append(placeList)
                     self.sortListsByDistance()
                 }
                 // No need to sort on success - already sorted above
             }
         }
     }

    
    
     // Returns unique users who saved a place, excluding the current logged-in user
     func getUniquePlaceSaversExcludingCurrentUser(forPlaceId placeId: String) -> [ProfileData] {
         guard let userIds = detailPlaceViewModel.placeSavers[placeId], let currentUserId = user?.id else { return [] }
         
         // Filter out the current user and map to ProfileData in userFollowing
         let uniqueUsers = userIds
             .filter { $0 != currentUserId }
             .compactMap { userId in
                 userFollowing.first(where: { $0.id == userId })
             }
         
         return uniqueUsers
     }
    
     func isPlaceInAnyList(placeId: String) -> Bool {
         return userListsPlaces.values.contains { $0.contains(placeId) }
     }

    /// Returns a dictionary mapping each PlaceList's id to the count of places in that list
    func placeCountsForAllLists() -> [UUID: Int] {
        var counts: [UUID: Int] = [:]
        for list in userLists {
            counts[list.id] = list.places.count
        }
        return counts
    }

    /// Returns the count of places in the PlaceList with the given id, or 0 if not found
    func placeCount(forListId listId: UUID) -> Int {
        return userLists.first(where: { $0.id == listId })?.places.count ?? 0
    }
    
    func refreshUserPlaces() async {
        // Combine all place IDs from favorites and all lists, then de-duplicate
        var allPlaceIds = Set(userFavorites)
        for list in userListsPlaces.values {
            allPlaceIds.formUnion(list)
        }
        await detailPlaceViewModel.refreshPlaces(detailPlaces: Array(allPlaceIds))
    }

    func loadMyReviewedPlacesWithPagination() {
        guard let userId = user?.id else { return }
        if allReviewedPlaceIds.isEmpty {
            isLoadingReviewedPlaces = true
            Task {
                do {
                    let restaurantReviews: [RestaurantReview] = try await reviewService.fetchUserReviews(userId: userId)
                    let genericReviews: [GenericReview] = try await reviewService.fetchUserReviews(userId: userId)
                    let allReviews: [ReviewProtocol] = restaurantReviews + genericReviews
                    allReviewedPlaceIds = Array(Set(allReviews.map { $0.placeId }))
                } catch {
                    isLoadingReviewedPlaces = false
                    return
                }
                if allReviewedPlaceIds.isEmpty {
                    isLoadingReviewedPlaces = false
                    return
                }
                await self.loadNextBatchOfMyReviews()
            }
        } else {
            Task { await self.loadNextBatchOfMyReviews() }
        }
    }

    private func loadNextBatchOfMyReviews() async {
        guard !isLoadingMoreReviews && _hasMoreReviews else {
            isLoadingReviewedPlaces = false
            return
        }
        isLoadingMoreReviews = true
        let startIndex = currentReviewPage * reviewsPerPage
        let endIndex = min(startIndex + reviewsPerPage, allReviewedPlaceIds.count)
        guard startIndex < allReviewedPlaceIds.count else {
            _hasMoreReviews = false
            isLoadingMoreReviews = false
            isLoadingReviewedPlaces = false
            return
        }
        let placeIdsToLoad = Array(allReviewedPlaceIds[startIndex..<endIndex])
        var successfullyLoadedPlaceIds: [String] = []
        for placeId in placeIdsToLoad {
            if detailPlaceViewModel.places[placeId] == nil {
                do {
                    let detailPlace = try await placeService.fetchPlace(withId: placeId)
                    detailPlaceViewModel.places[placeId] = detailPlace
                    detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    successfullyLoadedPlaceIds.append(placeId)
                } catch {
                    // Ignore failed loads
                }
            } else {
                successfullyLoadedPlaceIds.append(placeId)
            }
        }
        // Only add new place IDs
        let newPlaceIds = successfullyLoadedPlaceIds.filter { !loadedReviewedPlaceIds.contains($0) }
        loadedReviewedPlaceIds.append(contentsOf: newPlaceIds)
        currentReviewPage += 1
        _hasMoreReviews = endIndex < allReviewedPlaceIds.count
        isLoadingMoreReviews = false
        isLoadingReviewedPlaces = false
    }

    func loadMoreMyReviews() {
        Task { await self.loadNextBatchOfMyReviews() }
    }

    func getMyReviewedPlaces() -> [DetailPlace] {
        return loadedReviewedPlaceIds.compactMap { detailPlaceViewModel.places[$0] }
    }

    func resetMyReviewedPlacesPagination() {
        isLoadingReviewedPlaces = false
        isLoadingMoreReviews = false
        _hasMoreReviews = true
        currentReviewPage = 0
        allReviewedPlaceIds = []
        loadedReviewedPlaceIds = []
    }

    var hasMoreReviews: Bool { _hasMoreReviews }
    
    // MARK: - List Sorting by Distance
    
    private var hasPerformedInitialSort = false
    
    /// Calculates the average distance of all places in a list from the user's current location
    private func calculateAverageDistanceForList(_ list: PlaceList) -> Double {
        guard let currentLocation = locationManager.currentLocation else { 
            // If no location available, return infinity to sort these lists last
            return Double.infinity 
        }
        
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let placeCoordinate = detailPlace.coordinate {
                
                let placeLocation = CLLocation(
                    latitude: placeCoordinate.latitude,
                    longitude: placeCoordinate.longitude
                )
                
                let distance = currentLocation.distance(from: placeLocation)
                totalDistance += distance
                validPlaceCount += 1
            }
        }
        
        return validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
    }
    
    /// Sorts userLists by their average distance from the user's current location (closest first)
    /// Only sorts on app startup and when lists are modified
    func sortListsByDistance() {
        guard locationManager.currentLocation != nil else { return }
        
        userLists.sort { list1, list2 in
            let distance1 = calculateAverageDistanceForList(list1)
            let distance2 = calculateAverageDistanceForList(list2)
            return distance1 < distance2
        }
        
        hasPerformedInitialSort = true
    }

    /// Public method for manual refresh (if needed) - should only be called by user actions like pull-to-refresh
    func refreshListSorting() {
        sortListsByDistance()
    }
    
    /// Returns whether the initial sort has been performed
    var hasCompletedInitialSort: Bool {
        hasPerformedInitialSort
    }
    
    /// Formats distance for display (meters to miles/kilometers)
    private func formatDistance(_ distanceInMeters: Double) -> String {
        if distanceInMeters == Double.infinity {
            return "Unknown"
        }
        
        let miles = distanceInMeters * 0.000621371 // Convert meters to miles
        if miles < 1 {
            let feet = distanceInMeters * 3.28084 // Convert meters to feet
            return String(format: "%.0f ft", feet)
        } else if miles < 10 {
            return String(format: "%.1f mi", miles)
        } else {
            return String(format: "%.0f mi", miles)
        }
    }
    
    /// Returns the formatted average distance for a list
    func getAverageDistanceForList(_ list: PlaceList) -> String {
        let distance = calculateAverageDistanceForList(list)
        return formatDistance(distance)
    }

    /// Returns true if location is available for distance calculations
    var isLocationAvailable: Bool {
        return locationManager.currentLocation != nil
    }
    
    // MARK: - Place-Specific List Sorting
    
    /// Calculates the average distance of all places in a list from a specific place
    func calculateAverageDistanceForListFromPlace(_ list: PlaceList, place: DetailPlace) -> Double {
        guard let placeCoordinate = place.coordinate else { 
            // If no coordinate available for the place, return infinity to sort these lists last
            return Double.infinity 
        }
        
        let listPlaceIds = userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }
        
        let targetLocation = CLLocation(
            latitude: placeCoordinate.latitude,
            longitude: placeCoordinate.longitude
        )
        
        var totalDistance: Double = 0
        var validPlaceCount: Int = 0
        
        for placeId in listPlaceIds {
            if let detailPlace = detailPlaceViewModel.places[placeId],
               let listPlaceCoordinate = detailPlace.coordinate {
                
                let listPlaceLocation = CLLocation(
                    latitude: listPlaceCoordinate.latitude,
                    longitude: listPlaceCoordinate.longitude
                )
                
                let distance = targetLocation.distance(from: listPlaceLocation)
                totalDistance += distance
                validPlaceCount += 1
            }
        }
        
        return validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
    }
    
    /// Sorts lists by their proximity to a specific place (closest first)
    func sortListsByDistanceFromPlace(_ place: DetailPlace) -> [PlaceList] {
        return userLists.sorted { list1, list2 in
            let distance1 = calculateAverageDistanceForListFromPlace(list1, place: place)
            let distance2 = calculateAverageDistanceForListFromPlace(list2, place: place)
            return distance1 < distance2
        }
    }
    

}
