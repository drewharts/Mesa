//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import GooglePlaces
import MapboxSearch
import Foundation
import FirebaseFirestore
import UIKit

class ProfileViewModel: ObservableObject {
    @Published var data: ProfileData
    @Published var currentUser: User?
    @Published var placeListViewModels: [PlaceListViewModel] = []
    
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [DetailPlace]] = [:]
    @Published var listImages: [UUID: UIImage] = [:]
    
    @Published var userFavorites: [DetailPlace] = []
    @Published var placeImages: [String: UIImage] = [:]
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]
    @Published var profilePhoto: SwiftUI.Image? = nil
    @Published var profilePhotoImage: UIImage? = nil
    @Published private var userProfilePhotos: [String: UIImage] = [:]

    @Published var friends: [User] = []
    @Published var friendPlaces: [String: [DetailPlace]] = [:]
    @Published var followers: Int = 0
    @Published var following: Int = 0
    
    @Published var placeSavers: [String: [User]] = [:]
    @Published var placeLookup: [String: DetailPlace] = [:]
    @Published var placeAnnotationImages: [String: UIImage] = [:]
    
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
    public let userId: String
    private let mapboxSearchService = MapboxSearchService()
    
    @Published var showMaxFavoritesAlert: Bool = false
    @Published var isLoading: Bool = true
    
    init(data: ProfileData, firestoreService: FirestoreService, userId: String) {

        self.data = data
        self.firestoreService = firestoreService
        self.userId = userId
        
        let dispatchGroup = DispatchGroup()
        
        dispatchGroup.enter()
        fetchCurrentUser { [weak self] in
            guard let self = self else { return }
            self.fetchFavorites(user: self.currentUser!) {
                dispatchGroup.leave()
            }
        }
        
        loadPlaceLists()
        if let url = data.profilePhotoURL {
            loadImage(from: url)
        }
        
        dispatchGroup.enter()
        fetchLists(userId: userId) {
            self.fetchAllPlaceImages()
            dispatchGroup.leave()
        }
        
        fetchFollowers(userId: userId)
        fetchFollowing(userId: userId)
        
        dispatchGroup.enter()
        fetchFriends(userId: userId) {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
            print("All critical data fetched, isLoading set to false")
            print("placeSavers: \(self.placeSavers.count) places, placeAnnotationImages: \(self.placeAnnotationImages.count) images")
        }
    }
    
    func toggleFollowUser(userId: String) {
        // Check if the user is already in the friends list
        if let friendIndex = friends.firstIndex(where: { $0.id == userId }) {
            // User is currently followed, so unfollow them
            let friendToRemove = friends[friendIndex]
            friends.remove(at: friendIndex)
            
            // Immediately remove friend's places from the map
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.removeFriendPlaces(friendId: userId)
                print("Immediately removed places for unfollowed user \(userId) from map")
                
                // Update followers count asynchronously
                self.fetchFollowers(userId: self.userId)
                print("Successfully unfollowed user \(userId)")
            }
        } else {
            // User is not followed, so follow them
            firestoreService.fetchCurrentUser(userId: userId) { [weak self] user, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching user to follow \(userId): \(error.localizedDescription)")
                    return
                }
                guard let userToFollow = user else {
                    print("No user found with ID: \(userId)")
                    return
                }
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Add to local friends list
                    self.friends.append(userToFollow)
                    print("Successfully followed user \(userId)")
                    
                    // Load profile photo if available and fetch friend's data
                    if let photoURL = userToFollow.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: userId) {
                            // Immediately fetch and add friend's favorite places to the map
                            self.fetchFriendFavPlaces(friend: userToFollow) {
                                print("Finished fetching new friend's favorite places and added to map")
                            }
                            // Immediately fetch and add friend's lists to the map
                            self.fetchAndProcessFriendLists(friend: userToFollow) {
                                print("Finished fetching new friend's lists and added to map")
                            }
                        }
                    } else {
                        self.userProfilePhotos[userId] = nil
                        // Immediately fetch and add friend's data without waiting for photo
                        self.fetchFriendFavPlaces(friend: userToFollow) {
                            print("Finished fetching new friend's favorite places and added to map")
                        }
                        self.fetchAndProcessFriendLists(friend: userToFollow) {
                            print("Finished fetching new friend's lists and added to map")
                        }
                    }
                    
                    // Update followers count asynchronously
                    self.fetchFollowers(userId: self.userId)
                }
            }
        }
    }

    // Helper function to clean up friend's places when unfollowing
    private func removeFriendPlaces(friendId: String) {
        // Update placeSavers and placeAnnotationImages
        for (placeId, users) in placeSavers {
            if let index = users.firstIndex(where: { $0.id == friendId }) {
                var updatedUsers = users
                updatedUsers.remove(at: index)
                
                if updatedUsers.isEmpty {
                    // If no users left, remove the place entirely
                    placeSavers[placeId] = nil
                    placeLookup[placeId] = nil
                    placeAnnotationImages[placeId] = nil
                } else {
                    // Update with remaining users
                    placeSavers[placeId] = updatedUsers
                    let (image1, image2, image3) = getFirstThreeProfileImages(forKey: placeId)
                    placeAnnotationImages[placeId] = combinedCircularImage(image1: image1, image2: image2, image3: image3)
                }
            }
        }
    }
    
    private func fetchCurrentUser(completion: @escaping () -> Void) {
        firestoreService.fetchCurrentUser(userId: userId) { [weak self] user, error in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                if let error = error {
                    print("Error fetching current user: \(error.localizedDescription)")
                    self.currentUser = nil
                    completion()
                } else if let user = user {
                    self.currentUser = user
                    if let photoURL = user.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: user.id) {
                            completion()
                        }
                    } else {
                        completion()
                    }
                } else {
                    print("No user found for ID: \(self.userId)")
                    self.currentUser = nil
                    completion()
                }
            }
        }
    }
    
    private func fetchFavorites(user: User, completion: @escaping () -> Void) {
        print("Fetching favorites for user \(user.id)")
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] favorites in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                if favorites == nil {
                    print("Favorites fetch returned nil - possible error or no data")
                } else {
                    print("Fetched \(favorites!.count) favorites")
                }
                self.userFavorites = favorites ?? []
                guard let favorites = favorites, !favorites.isEmpty else {
                    print("No favorites to process")
                    self.fetchFavoritePlaceImages()
                    completion()
                    return
                }
                for favorite in favorites {
                    let placeId = favorite.id.uuidString
                    if self.placeSavers[placeId] != nil {
                        if !self.placeSavers[placeId]!.contains(where: { $0.id == user.id }) {
                            self.placeSavers[placeId]!.append(user)
                        }
                    } else {
                        self.placeSavers[placeId] = [user]
                    }
                    self.placeLookup[placeId] = favorite
                    let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                    self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                    print("Added favorite \(placeId) to placeSavers, placeLookup, and placeAnnotationImages")
                }
                self.fetchFavoritePlaceImages()
                completion()
            }
        }
    }
    
    func fetchFriends(userId: String, completion: @escaping () -> Void) {
        firestoreService.fetchFollowingProfiles(for: userId) { [weak self] profiles, error in
            guard let self = self else { completion(); return }
            if let error = error {
                print("Error fetching friends: \(error.localizedDescription)")
                DispatchQueue.main.async { completion() }
                return
            }
            
            self.friends = profiles ?? []
            guard !self.friends.isEmpty else {
                completion()
                return
            }
            
            var pendingTasks = self.friends.count * 2 // Two tasks per friend: favorites and lists
            
            for friend in self.friends {
                if let photoURL = friend.profilePhotoURL {
                    self.loadUserProfilePhoto(from: photoURL, forUserId: friend.id) {
                        // Fetch favorite places
                        self.fetchFriendFavPlaces(friend: friend) {
                            pendingTasks -= 1
                            if pendingTasks == 0 {
                                completion()
                            }
                        }
                        // Fetch and process lists
                        self.fetchAndProcessFriendLists(friend: friend) {
                            pendingTasks -= 1
                            if pendingTasks == 0 {
                                completion()
                            }
                        }
                    }
                } else {
                    self.userProfilePhotos[friend.id] = nil
                    // Fetch favorite places
                    self.fetchFriendFavPlaces(friend: friend) {
                        pendingTasks -= 1
                        if pendingTasks == 0 {
                            completion()
                        }
                    }
                    // Fetch and process lists
                    self.fetchAndProcessFriendLists(friend: friend) {
                        pendingTasks -= 1
                        if pendingTasks == 0 {
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    func fetchFriendFavPlaces(friend: User, completion: @escaping () -> Void) {
        print("Starting fetch for friend \(friend.id)")
        firestoreService.fetchProfileFavorites(userId: friend.id) { [weak self] places in
            guard let self = self else { completion(); return }
            if let places = places {
                DispatchQueue.main.async {
                    print("Updating \(places.count) places for friend \(friend.id)")
                    for place in places {
                        let placeId = place.id.uuidString
                        if self.placeSavers[placeId] != nil {
                            if !self.placeSavers[placeId]!.contains(where: { $0.id == friend.id }) {
                                self.placeSavers[placeId]!.append(friend)
                            }
                        } else {
                            self.placeSavers[placeId] = [friend]
                        }
                        self.placeLookup[placeId] = place
                        let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                        self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                    }
                    print("Finished fetching friend \(friend.id)'s favorite places. placeSavers count: \(self.placeSavers.count)")
                    completion()
                }
            } else {
                print("No places fetched for friend \(friend.id)")
                completion()
            }
        }
    }
    
    func getAllDetailPlaces() -> [DetailPlace] {
        placeSavers.keys.compactMap { placeLookup[$0] }
    }
    
    public func getFirstThreeProfileImages(forKey key: String) -> (UIImage?, UIImage?, UIImage?) {
        guard let users = placeSavers[key] else {
            print("No users found for place ID: \(key)")
            return (nil, nil, nil)
        }
        
        let firstThreeUsers = users.prefix(3)
        print("Place ID: \(key)")
        print("  Users: \(firstThreeUsers.map { $0.id })")
        
        let images = firstThreeUsers.map { user in
            let photo = userProfilePhotos[user.id]
            print("    User \(user.id): Photo \(photo != nil ? "present" : "nil")")
            return photo
        }
        
        let paddedImages = (images + [nil, nil, nil]).prefix(3)
        print("  Images: image1=\(paddedImages[0] != nil ? "present" : "nil"), image2=\(paddedImages[1] != nil ? "present" : "nil"), image3=\(paddedImages[2] != nil ? "present" : "nil")")
        
        return (paddedImages[0], paddedImages[1], paddedImages[2])
    }
    
    private func combinedCircularImage(image1: UIImage?, image2: UIImage? = nil, image3: UIImage? = nil) -> UIImage {
        let totalSize = CGSize(width: 60, height: 40)
        let singleCircleSize = CGSize(width: 40, height: 40)
        let renderer = UIGraphicsImageRenderer(size: totalSize)
        
        return renderer.image { context in
            let firstRect = CGRect(x: 0, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let secondRect = CGRect(x: 15, y: 0, width: singleCircleSize.width, height: singleCircleSize.height)
            let thirdRect = CGRect(x: 10, y: 10, width: singleCircleSize.width, height: singleCircleSize.height)
            
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
            drawCircularImage(image1 ?? UIImage(named: "DestPin")!, in: firstRect)
        }
    }
    
    func fetchAllPlaceImages() {
        print("Starting fetchAllPlaceImages for all places")
        
        // Get all unique places from placeLookup
        let allPlaces = Array(placeLookup.values)
        print("Processing \(allPlaces.count) total places")
        
        for place in allPlaces {
            let placeId = place.id.uuidString
            
            // Skip if image already exists
            if placeImages[placeId] != nil {
                print("Image already exists for place \(placeId), skipping fetch")
                continue
            }
            
            // First try the latest review
            firestoreService.fetchReviews(placeId: placeId, latestOnly: true) { [weak self] (latestReviews, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching latest review for place \(placeId): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.placeImages[placeId] = nil
                    }
                    return
                }
                
                // Check if latest review has an image
                if let firstReview = latestReviews?.first,
                   let firstPhotoURLString = firstReview.images.first,
                   let url = URL(string: firstPhotoURLString) {
                    
                    self.fetchImage(from: url, for: placeId)
                } else {
                    // If no image in latest review, fetch all reviews
                    self.firestoreService.fetchReviews(placeId: placeId, latestOnly: false) { (allReviews, error) in
                        if let error = error {
                            print("Error fetching all reviews for place \(placeId): \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.placeImages[placeId] = nil
                            }
                            return
                        }
                        
                        // Look through all reviews for the first available image
                        if let reviews = allReviews {
                            print("Checking \(reviews.count) reviews for place \(placeId)")
                            for review in reviews {
                                if let photoURLString = review.images.first,
                                   let url = URL(string: photoURLString) {
                                    self.fetchImage(from: url, for: placeId)
                                    return // Exit after finding the first image
                                }
                            }
                            // If no images found in any review
                            DispatchQueue.main.async {
                                self.placeImages[placeId] = nil
                                print("No images found in any reviews for place \(placeId)")
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.placeImages[placeId] = nil
                                print("No reviews available for place \(placeId)")
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper function to fetch and store the image
    private func fetchImage(from url: URL, for placeId: String) {
        print("Fetching image from URL: \(url.absoluteString) for place \(placeId)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading image for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.placeImages[placeId] = nil
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    // Only store if no image exists yet
                    if self.placeImages[placeId] == nil {
                        self.placeImages[placeId] = image
                        print("Loaded and stored image for place \(placeId) into placeImages")
                    } else {
                        print("Image already stored for \(placeId), skipping update")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.placeImages[placeId] = nil
                    print("No image data for place \(placeId)")
                }
            }
        }.resume()
    }
    
    func fetchFavoritePlaceImages() {
        print("Starting fetchFavoritePlaceImages for \(userFavorites.count) favorites")
        
        for place in userFavorites {
            let placeId = place.id.uuidString
            
            // Skip if image already exists in favoritePlaceImages
            if favoritePlaceImages[placeId] != nil {
                print("Image already exists for favorite place \(placeId), skipping fetch")
                continue
            }
            
            // First try the latest review
            firestoreService.fetchReviews(placeId: placeId, latestOnly: true) { [weak self] (latestReviews, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching latest review for place \(placeId): \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.favoritePlaceImages[placeId] = nil
                        self.placeImages[placeId] = nil
                    }
                    return
                }
                
                // Check if latest review has an image
                if let firstReview = latestReviews?.first,
                   let firstPhotoURLString = firstReview.images.first,
                   let url = URL(string: firstPhotoURLString) {
                    
                    self.fetchFavoriteImage(from: url, for: placeId)
                } else {
                    // If no image in latest review, fetch all reviews
                    self.firestoreService.fetchReviews(placeId: placeId, latestOnly: false) { (allReviews, error) in
                        if let error = error {
                            print("Error fetching all reviews for place \(placeId): \(error.localizedDescription)")
                            DispatchQueue.main.async {
                                self.favoritePlaceImages[placeId] = nil
                                self.placeImages[placeId] = nil
                            }
                            return
                        }
                        
                        // Look through all reviews for the first available image
                        if let reviews = allReviews {
                            print("Checking \(reviews.count) reviews for place \(placeId)")
                            for review in reviews {
                                if let photoURLString = review.images.first,
                                   let url = URL(string: photoURLString) {
                                    self.fetchFavoriteImage(from: url, for: placeId)
                                    return // Exit after finding the first image
                                }
                            }
                            // If no images found in any review
                            DispatchQueue.main.async {
                                self.favoritePlaceImages[placeId] = nil
                                self.placeImages[placeId] = nil
                                print("No images found in any reviews for favorite place \(placeId)")
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.favoritePlaceImages[placeId] = nil
                                self.placeImages[placeId] = nil
                                print("No reviews available for favorite place \(placeId)")
                            }
                        }
                    }
                }
            }
        }
    }

    // Helper function to fetch and store the favorite place image
    private func fetchFavoriteImage(from url: URL, for placeId: String) {
        print("Fetching image from URL: \(url.absoluteString) for favorite place \(placeId)")
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading image for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.favoritePlaceImages[placeId] = nil
                    self.placeImages[placeId] = nil
                }
                return
            }
            
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    // Only store if no image exists yet
                    if self.favoritePlaceImages[placeId] == nil {
                        self.favoritePlaceImages[placeId] = image
                        self.placeImages[placeId] = image
                        print("Loaded and stored image for favorite place \(placeId)")
                    } else {
                        print("Image already stored for favorite place \(placeId), skipping update")
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.favoritePlaceImages[placeId] = nil
                    self.placeImages[placeId] = nil
                    print("No image data for favorite place \(placeId)")
                }
            }
        }.resume()
    }
    private func loadUserProfilePhoto(from url: URL, forUserId userId: String, completion: (() -> Void)? = nil) {
        if userProfilePhotos[userId] != nil {
            completion?()
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion?(); return }
            if let error = error {
                print("Error loading profile photo for user \(userId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.userProfilePhotos[userId] = nil
                    completion?()
                }
                return
            }
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.userProfilePhotos[userId] = uiImage
                    print("Loaded profile photo for \(userId)")
                    completion?()
                }
            } else {
                DispatchQueue.main.async {
                    self.userProfilePhotos[userId] = nil
                    print("Failed to load profile photo for \(userId): No image data")
                    completion?()
                }
            }
        }.resume()
    }

    func profilePhoto(forUserId userId: String) -> UIImage? {
        return userProfilePhotos[userId] ?? UIImage(named: "defaultProfile")
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
    func fetchFollowing(userId: String) {
        firestoreService.getNumberFollowing(forUserId: userId) { (count, error) in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                return
            }
            self.following = count
        }
    }
    
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let places = placeListGMSPlaces[listId] else {
            return false
        }
        return places.contains { $0.id.uuidString == placeId }
    }
    
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        let newPlace = Place(id: place.id, name: place.name, address: place.address!)
        placeListGMSPlaces[listId, default: []].append(place)
        firestoreService.addPlaceToList(userId: userId, listName: listId.uuidString, place: newPlace)
        firestoreService.addToAllPlaces(detailPlace: place) { error in
            if let error = error {
                print("Error adding place: \(error.localizedDescription)")
            } else {
                print("Place added successfully!")
            }
            self.fetchAllPlaceImages() // Add this to fetch image for the new place
        }
        // Update dictionaries for the new list place
        let placeId = place.id.uuidString
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let user = self.currentUser else { return }
            if self.placeSavers[placeId] != nil {
                if !self.placeSavers[placeId]!.contains(where: { $0.id == user.id }) {
                    self.placeSavers[placeId]!.append(user)
                }
            } else {
                self.placeSavers[placeId] = [user]
            }
            self.placeLookup[placeId] = place
            let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
            self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
            print("Added list place \(placeId) to placeSavers, placeLookup, and placeAnnotationImages")
        }
    }
    
    private func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        firestoreService.findPlace(mapboxId: place.mapboxId!) { [weak self] existingDetailPlace, error in
            if let error = error {
                print("Error checking for existing place: \(error.localizedDescription)")
            }
            if let existingDetailPlace = existingDetailPlace {
                completion(existingDetailPlace)
                return
            }
            let uuid = UUID(uuidString: place.id) ?? UUID()
            var detailPlace = DetailPlace(id: uuid, name: place.name, address: place.address?.formattedAddress(style: .medium) ?? "",city: place.address?.place ?? "")
            detailPlace.mapboxId = place.mapboxId
            detailPlace.coordinate = GeoPoint(latitude: Double(place.coordinate.latitude), longitude: Double(place.coordinate.longitude))
            detailPlace.categories = place.categories
            detailPlace.phone = place.metadata?.phone
            detailPlace.rating = place.metadata?.rating ?? 0
            detailPlace.description = place.metadata?.description ?? ""
            detailPlace.priceLevel = place.metadata?.priceLevel
            detailPlace.reservable = place.metadata?.reservable ?? false
            detailPlace.servesBreakfast = place.metadata?.servesBreakfast ?? false
            detailPlace.serversLunch = place.metadata?.servesLunch ?? false
            detailPlace.serversDinner = place.metadata?.servesDinner ?? false
            detailPlace.Instagram = place.metadata?.instagram
            detailPlace.X = place.metadata?.twitter
            self?.firestoreService.addToAllPlaces(detailPlace: detailPlace) { error in
                if let error = error {
                    print("Error saving new place to Firestore: \(error.localizedDescription)")
                }
            }
            completion(detailPlace)
        }
    }
    
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        if var places = placeListGMSPlaces[listId] {
            places.removeAll { $0.id.uuidString == place.id.uuidString }
            placeListGMSPlaces[listId] = places
        }
        firestoreService.removePlaceFromList(userId: userId, listName: listId.uuidString, placeId: place.id.uuidString)
        // Update dictionaries if the place is no longer associated with the user
        let placeId = place.id.uuidString
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let currentUser = self.currentUser else { return }
            if let users = self.placeSavers[placeId], users.count == 1, users.first?.id == currentUser.id {
                self.placeSavers[placeId] = nil
                self.placeLookup[placeId] = nil
                self.placeAnnotationImages[placeId] = nil
            } else if var users = self.placeSavers[placeId] {
                users.removeAll { $0.id == currentUser.id }
                self.placeSavers[placeId] = users
                let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
            }
        }
    }
    
    private func fetchAndProcessFriendLists(friend: User, completion: @escaping () -> Void) {
        firestoreService.fetchLists(userId: friend.id) { [weak self] lists in
            guard let self = self else { completion(); return }
            guard !lists.isEmpty else {
                completion()
                return
            }
            
            var pendingFetches = lists.count
            for list in lists {
                self.fetchFirestorePlaces(for: list.places) { gmsPlaces in
                    for place in gmsPlaces {
                        let placeId = place.id.uuidString
                        // Update placeSavers
                        if self.placeSavers[placeId] != nil {
                            if !self.placeSavers[placeId]!.contains(where: { $0.id == friend.id }) {
                                self.placeSavers[placeId]!.append(friend)
                            }
                        } else {
                            self.placeSavers[placeId] = [friend]
                        }
                        // Update placeLookup
                        self.placeLookup[placeId] = place
                        // Update placeAnnotationImages
                        let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                        self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                        print("Added friend's list place \(placeId) to placeSavers, placeLookup, and placeAnnotationImages")
                    }
                    pendingFetches -= 1
                    if pendingFetches == 0 {
                        completion()
                    }
                }
            }
        }
    }
    
    private func fetchLists(userId: String, completion: @escaping () -> Void = {}) {
        firestoreService.fetchLists(userId: userId) { [weak self] lists in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                self.userLists = lists
                guard !lists.isEmpty else {
                    completion()
                    return
                }
                
                var pendingFetches = lists.count
                for list in lists {
                    self.fetchListImage(for: list)
                    self.fetchFirestorePlaces(for: list.places) { [weak self] gmsPlaces in
                        guard let self = self, let currentUser = self.currentUser else { return }
                        self.placeListGMSPlaces[list.id] = gmsPlaces
                        for place in gmsPlaces {
                            let placeId = place.id.uuidString
                            if self.placeSavers[placeId] != nil {
                                if !self.placeSavers[placeId]!.contains(where: { $0.id == currentUser.id }) {
                                    self.placeSavers[placeId]!.append(currentUser)
                                }
                            } else {
                                self.placeSavers[placeId] = [currentUser]
                            }
                            self.placeLookup[placeId] = place
                            let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                            self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                            print("Added list place \(placeId) to placeSavers, placeLookup, and placeAnnotationImages from list \(list.id)")
                        }
                        pendingFetches -= 1
                        if pendingFetches == 0 {
                            completion()
                        }
                    }
                }
            }
        }
    }
    
    private func fetchListImage(for list: PlaceList) {
        guard let imageUrlString = list.image, let url = URL(string: imageUrlString) else { return }
        if listImages[list.id] != nil { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.listImages[list.id] = image
            }
        }.resume()
    }
    
    func removeFavoritePlace(place: DetailPlace) {
        if let index = userFavorites.firstIndex(where: { $0.id.uuidString == place.id.uuidString }) {
            userFavorites.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: place.id.uuidString)
            if let users = placeSavers[place.id.uuidString], !users.isEmpty {
                let (image1, image2, image3) = getFirstThreeProfileImages(forKey: place.id.uuidString)
                placeAnnotationImages[place.id.uuidString] = combinedCircularImage(image1: image1, image2: image2, image3: image3)
            } else {
                placeAnnotationImages[place.id.uuidString] = nil
            }
        }
    }
    
    func addFavoriteFromSuggestion(_ suggestion: SearchSuggestion) {
        print("🔍 User selected suggestion: \(suggestion.id) - \(suggestion.name)")
        mapboxSearchService.selectSuggestion(suggestion) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                print("✅ Resolved result: \(result.id) - \(result.name)")
                self.searchResultToDetailPlace(place: result) { place in
                    self.userFavorites.append(place)
                    self.firestoreService.addProfileFavorite(userId: self.userId, place: place)
                    self.fetchFavoritePlaceImages()
                    let placeId = place.id.uuidString
                    if self.placeSavers[placeId] != nil {
                        if !self.placeSavers[placeId]!.contains(where: { $0.id == self.userId }) {
                            self.placeSavers[placeId]!.append(self.currentUser!)
                        }
                    } else {
                        self.placeSavers[placeId] = [self.currentUser!]
                    }
                    self.placeLookup[placeId] = place
                    let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                    self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                }
            }
        }
    }
    
    func numberOfFavoritePlaces() -> Int {
        return favoritePlaceViewModels.count
    }
    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
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
    
    func loadPlaceLists() {
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.placeListViewModels = placeLists.map { placeList in
                    PlaceListViewModel(placeList: placeList, firestoreService: self.firestoreService, userId: self.userId)
                }
            }
        }
    }
    
    func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.profilePhoto = Image(uiImage: uiImage)
                self?.profilePhotoImage = uiImage
            }
        }.resume()
    }
    
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
        let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
        userLists.append(newPlaceList)
        firestoreService.createNewList(placeList: newPlaceList, userID: userId)
    }
    
    func removePlaceList(placeList: PlaceList) {
        if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
            userLists.remove(at: index)
            firestoreService.deleteList(userId: self.userId, listName: placeList.name) { error in
                if let error = error {
                    print("Failed to delete list: \(error.localizedDescription)")
                } else {
                    if let index = self.userLists.firstIndex(where: { $0.id == placeList.id }) {
                        self.userLists.remove(at: index)
                    }
                }
            }
        }
    }
}
