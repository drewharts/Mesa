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

class ProfileViewModel: ObservableObject {
    @Published var data: ProfileData
    @Published var currentUser: User?
    @Published var placeListViewModels: [PlaceListViewModel] = []
    
    @Published var userLists: [PlaceList] = []
    @Published var placeListMBPlaces: [UUID: [String]] = [:] // Now stores place IDs
    @Published var listImages: [UUID: UIImage] = [:]
    
    @Published var userFavorites: [String] = [] // Now stores place IDs
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var profilePhoto: SwiftUI.Image? = nil
    @Published var profilePhotoImage: UIImage? = nil
    @Published private var userProfilePhotos: [String: UIImage] = [:] //userID : Profile Picture

    @Published var friends: [User] = []
    @Published var followers: Int = 0
    @Published var following: Int = 0
    @Published var placeSaversByPlace: [String: [User]] = [:] // Maps place IDs to users who saved them
    
    @Published var placeAnnotationImages: [String: UIImage] = [:] // Still here for now
    
    private let firestoreService: FirestoreService
    private let profileFirestoreService = ProfileFirestoreService()
    private let detailPlaceViewModel: DetailPlaceViewModel
    public let userId: String
    private let mapboxSearchService = MapboxSearchService()
    
    @Published var showMaxFavoritesAlert: Bool = false
    @Published var isLoading: Bool = true
    
    init(data: ProfileData, firestoreService: FirestoreService, detailPlaceViewModel: DetailPlaceViewModel, userId: String) {
        self.data = data
        self.firestoreService = firestoreService
        self.detailPlaceViewModel = detailPlaceViewModel
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
            dispatchGroup.leave()
        }
        
        fetchFollowers(userId: userId)
        fetchFollowing(userId: userId)
        
        dispatchGroup.enter()
        processFollowedUsersAndPlaces { [weak self] in
            guard let self = self else { return }
            self.fetchUserReviewedPlaces {
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
    }
    
    func changeProfilePhoto(_ newImage: UIImage) async {
        // Crop the image to a square
        let squareImage = cropToSquare(newImage)
        
        do {
            let newPhotoURL = try await firestoreService.updateProfilePhoto(userId: userId, image: squareImage)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.profilePhotoImage = squareImage
                self.profilePhoto = Image(uiImage: squareImage)
                self.data.profilePhotoURL = newPhotoURL
                
                // Update profile picture across all reviews
                self.firestoreService.updateProfilePictureAcrossAllReviews(userId: self.userId, newProfilePictureURL: newPhotoURL.absoluteString) { error in
                    if let error = error {
                        print("Error updating profile pictures in reviews: \(error.localizedDescription)")
                        // You might want to show an alert to the user here
                    } else {
                        print("Successfully updated profile pictures across all reviews")
                    }
                }
            }
        } catch {
            print("Error updating profile photo: \(error)")
            // You might want to handle the error here, perhaps show an alert to the user
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
        if let friendIndex = friends.firstIndex(where: { $0.id == userId }) {
            let friendToRemove = friends[friendIndex]
            friends.remove(at: friendIndex)
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // No need for removeFriendPlaces; DetailPlaceViewModel manages placeSavers
                self.fetchFollowers(userId: self.userId)
                print("Successfully unfollowed user \(userId)")
            }
        } else {
            firestoreService.fetchCurrentUser(userId: userId) { [weak self] user, error in
                guard let self = self else { return }
                if let userToFollow = user {
                    DispatchQueue.main.async { [weak self] in
                        guard let self = self else { return }
                        self.friends.append(userToFollow)
                        if let photoURL = userToFollow.profilePhotoURL {
                            self.loadUserProfilePhoto(from: photoURL, forUserId: userToFollow.id) {
                                self.fetchFriendFavPlaces(friend: userToFollow) {}
                                self.fetchAndProcessFriendLists(friend: userToFollow) {}
                            }
                        } else {
                            self.userProfilePhotos[userToFollow.id] = nil
                            self.fetchFriendFavPlaces(friend: userToFollow) {}
                            self.fetchAndProcessFriendLists(friend: userToFollow) {}
                        }
                        self.fetchFollowers(userId: self.userId)
                        print("Successfully followed user \(userId)")
                    }
                }
            }
        }
    }
    
    private func fetchCurrentUser(completion: @escaping () -> Void) {
        firestoreService.fetchCurrentUser(userId: userId) { [weak self] user, error in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                self.currentUser = user
                if let user = user, let photoURL = user.profilePhotoURL {
                    self.loadUserProfilePhoto(from: photoURL, forUserId: user.id) {
                        completion()
                    }
                } else {
                    completion()
                }
            }
        }
    }
    
    private func fetchFavorites(user: User, completion: @escaping () -> Void) {
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] favorites in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                let favoriteIds = favorites?.map { $0.id.uuidString } ?? []
                self.userFavorites = favoriteIds
                
                for place in favorites ?? [] {
                    let placeId = place.id.uuidString
                    self.detailPlaceViewModel.places[placeId] = place
                    self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: user)
                    // Add to our placeSaversByPlace dictionary
                    self.placeSaversByPlace[placeId, default: []].append(user)
                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    self.updatePlaceAnnotationImages(for: placeId)
                }
                
                completion()
            }
        }
    }
    
    func fetchFriends(userId: String, completion: @escaping () -> Void) {
        firestoreService.fetchFollowingProfiles(for: userId) { [weak self] profiles, error in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                self.friends = profiles ?? []
                guard !self.friends.isEmpty else { completion(); return }
                
                var pendingTasks = self.friends.count
                for friend in self.friends {
                    if let photoURL = friend.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: friend.id) {
                            self.fetchFriendFavPlaces(friend: friend) { 
                                self.fetchAndProcessFriendLists(friend: friend) {
                                    pendingTasks -= 1
                                    if pendingTasks == 0 { completion() }
                                }
                            }
                        }
                    } else {
                        self.userProfilePhotos[friend.id] = nil
                        self.fetchFriendFavPlaces(friend: friend) { 
                            self.fetchAndProcessFriendLists(friend: friend) {
                                pendingTasks -= 1
                                if pendingTasks == 0 { completion() }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func fetchFriendFavPlaces(friend: User, completion: @escaping () -> Void) {
        firestoreService.fetchProfileFavorites(userId: friend.id) { [weak self] places in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                for place in places ?? [] {
                    let placeId = place.id.uuidString
                    self.detailPlaceViewModel.places[placeId] = place
                    self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: friend)
                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    self.updatePlaceAnnotationImages(for: placeId)
                }
                completion()
            }
        }
    }
    
    func getAllDetailPlaces() -> [DetailPlace] {
        detailPlaceViewModel.places.values.map { $0 }
    }
    
    public func getFirstThreeProfileImages(forKey key: String) -> (UIImage?, UIImage?, UIImage?) {
        guard let users = detailPlaceViewModel.placeSavers[key], !users.isEmpty else {
            print("CREATING DEFAULT PROFILE IMAGES BC NO USERS FOUND")
            let defaultImage = UIImage(named: "defaultProfile")
            return (defaultImage, nil, nil)
        }
        
        let firstThreeUsers = users.prefix(3)
        let images = firstThreeUsers.map { user -> UIImage? in
            if let photo = self.userProfilePhotos[user.id] {
                return photo
            } else {
                // Return default image since we should have loaded all photos by now
                return UIImage(named: "defaultProfile")
            }
        }
        
        let paddedImages = (images + [nil, nil, nil]).prefix(3)
        return (paddedImages[0], paddedImages[1], paddedImages[2])
    }
    
    private func ensureProfilePhotosLoaded(for users: [User], completion: @escaping () -> Void) {
        if users.isEmpty {
            completion()
            return
        }

        let dispatchGroup = DispatchGroup()
        
        for user in users {
            dispatchGroup.enter()
            if userProfilePhotos[user.id] == nil {
                if let photoURL = user.profilePhotoURL {
                    loadUserProfilePhoto(from: photoURL, forUserId: user.id) {
                        dispatchGroup.leave()
                    }
                } else {
                    // No photo URL, set a default image
                    DispatchQueue.main.async {
                        self.userProfilePhotos[user.id] = UIImage(named: "defaultProfile")
                        dispatchGroup.leave()
                    }
                }
            } else {
                // Already loaded
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion()
        }
    }
    
    private func updatePlaceAnnotationImages(for placeId: String) {
        guard let users = detailPlaceViewModel.placeSavers[placeId] else { return }
        
        ensureProfilePhotosLoaded(for: Array(users)) { [weak self] in
            guard let self = self else { return }
            let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
            self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
        }
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
            if image1 != nil { drawCircularImage(image1, in: firstRect) }
        }
    }
    
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let placeIds = placeListMBPlaces[listId] else { return false }
        return placeIds.contains(placeId)
    }
    
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        let placeId = place.id.uuidString
        placeListMBPlaces[listId, default: []].append(placeId)
        let newPlace = Place(id: place.id, name: place.name, address: place.address!)
        firestoreService.addPlaceToList(userId: userId, listName: listId.uuidString, place: newPlace)
        firestoreService.addToAllPlaces(detailPlace: place) { [weak self] error in
            guard let self = self else { return }
            if error == nil {
                self.detailPlaceViewModel.places[placeId] = place
                if let user = self.currentUser {
                    self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: user)
                    // Add to placeSaversByPlace dictionary
                    self.placeSaversByPlace[placeId, default: []].append(user)
                }
                self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                self.updatePlaceAnnotationImages(for: placeId)
            }
        }
    }
    
    private func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        detailPlaceViewModel.searchResultToDetailPlace(place: place, completion: completion)
    }
    
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        let placeId = place.id.uuidString
        if var placeIds = placeListMBPlaces[listId] {
            placeIds.removeAll { $0 == placeId }
            placeListMBPlaces[listId] = placeIds
        }
        firestoreService.removePlaceFromList(userId: userId, listName: listId.uuidString, placeId: placeId)
        self.updatePlaceAnnotationImages(for: placeId)
    }
    
    private func fetchAndProcessFriendLists(friend: User, completion: @escaping () -> Void) {
        firestoreService.fetchLists(userId: friend.id) { [weak self] lists in
            guard let self = self else { completion(); return }
            guard !lists.isEmpty else { completion(); return }
            
            var pendingFetches = lists.count
            for list in lists {
                self.fetchFirestorePlaces(for: list.places) { gmsPlaces in
                    for place in gmsPlaces {
                        let placeId = place.id.uuidString
                        self.detailPlaceViewModel.places[placeId] = place
                        self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: friend)
                        self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                        self.updatePlaceAnnotationImages(for: placeId)
                    }
                    pendingFetches -= 1
                    if pendingFetches == 0 { completion() }
                }
            }
        }
    }
    
    private func fetchLists(userId: String, completion: @escaping () -> Void = {}) {
        firestoreService.fetchLists(userId: userId) { [weak self] lists in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                self.userLists = lists
                guard !lists.isEmpty else { completion(); return }
                
                var pendingFetches = lists.count
                for list in lists {
                    self.fetchListImage(for: list)
                    self.fetchFirestorePlaces(for: list.places) { gmsPlaces in
                        let placeIds = gmsPlaces.map { $0.id.uuidString }
                        self.placeListMBPlaces[list.id] = placeIds
                        if let currentUser = self.currentUser {
                            for place in gmsPlaces {
                                let placeId = place.id.uuidString
                                self.detailPlaceViewModel.places[placeId] = place
                                self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: currentUser)
                                // Add to our placeSaversByPlace dictionary
                                self.placeSaversByPlace[placeId, default: []].append(currentUser)
                                self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                                self.updatePlaceAnnotationImages(for: placeId)
                            }
                        }
                        pendingFetches -= 1
                        if pendingFetches == 0 { completion() }
                    }
                }
            }
        }
    }
    
    private func fetchListImage(for list: PlaceList) {
        guard let imageUrlString = list.image, let url = URL(string: imageUrlString) else { return }
        if listImages[list.id] != nil { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async { self.listImages[list.id] = image }
        }.resume()
    }
    
    func removeFavoritePlace(place: DetailPlace) {
        let placeId = place.id.uuidString
        if let index = userFavorites.firstIndex(of: placeId) {
            userFavorites.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: placeId)
            let (image1, image2, image3) = getFirstThreeProfileImages(forKey: placeId)
            placeAnnotationImages[placeId] = combinedCircularImage(image1: image1, image2: image2, image3: image3)
        }
    }
    
    func addFavoriteFromSuggestion(_ suggestion: SearchSuggestion) {
        mapboxSearchService.selectSuggestion(suggestion) { [weak self] result in
            guard let self = self else { return }
            self.detailPlaceViewModel.searchResultToDetailPlace(place: result) { place in
                let placeId = place.id.uuidString
                DispatchQueue.main.async {
                    self.userFavorites.append(placeId)
                    self.firestoreService.addProfileFavorite(userId: self.userId, place: place)
                    if let user = self.currentUser {
                        self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: user)
                    }
                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    self.updatePlaceAnnotationImages(for: placeId)
                }
            }
        }
    }
    
    func numberOfFavoritePlaces() -> Int {
        return userFavorites.count // Updated to reflect ID-based storage
    }
    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
    }
    
    func fetchFirestorePlaces(for places: [Place], completion: @escaping ([DetailPlace]) -> Void) {
        var fetchedPlaces: [DetailPlace] = []
        let dispatchGroup = DispatchGroup()

        for place in places {
            let placeId = place.id.uuidString
            dispatchGroup.enter()
            detailPlaceViewModel.fetchPlaceDetails(placeId: placeId) { detailPlace in
                if let detailPlace = detailPlace {
                    fetchedPlaces.append(detailPlace)
                }
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async { completion(fetchedPlaces) }
        }
    }
    
    func loadPlaceLists() {
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.placeListViewModels = placeLists.map {
                    PlaceListViewModel(placeList: $0, firestoreService: self.firestoreService, userId: self.userId)
                }
            }
        }
    }
    
    func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
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
                if error == nil, let index = self.userLists.firstIndex(where: { $0.id == placeList.id }) {
                    self.userLists.remove(at: index)
                }
            }
        }
    }
    
    // Helpers
    private func loadUserProfilePhoto(from url: URL, forUserId userId: String, completion: @escaping () -> Void) {
        if userProfilePhotos[userId] != nil { completion(); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { completion(); return }
            DispatchQueue.main.async {
                self.userProfilePhotos[userId] = data.flatMap { UIImage(data: $0) }
                completion()
            }
        }.resume()
    }

    func profilePhoto(forUserId userId: String) -> UIImage? {
        userProfilePhotos[userId] ?? UIImage(named: "defaultProfile")
    }
    
    func fetchFollowers(userId: String) {
        firestoreService.getNumberFollowers(forUserId: userId) { [weak self] (count, _) in
            self?.followers = count
        }
    }
    
    func fetchFollowing(userId: String) {
        firestoreService.getNumberFollowing(forUserId: userId) { [weak self] (count, _) in
            self?.following = count
        }
    }
    
    func fetchUserReviewedPlaces(completion: @escaping () -> Void = {}) {
        guard let currentUser = currentUser else { 
            completion()
            return 
        }
        
        // First fetch current user's reviews
        firestoreService.fetchUserReviewPlaces(userId: userId, user: currentUser) { [weak self] places, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                if let places = places {
                    for place in places {
                        let placeId = place.id.uuidString
                        self.detailPlaceViewModel.places[placeId] = place
                        self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: currentUser)
                        // Add to placeSaversByPlace dictionary
                        self.placeSaversByPlace[placeId, default: []].append(currentUser)
                        self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                        self.updatePlaceAnnotationImages(for: placeId)
                    }
                }
                
                // Then fetch reviews for each friend
                var pendingTasks = self.friends.count
                for friend in self.friends {
                    self.fetchFriendReviewedPlaces(friend: friend) {
                        pendingTasks -= 1
                        if pendingTasks == 0 {
                            completion()
                        }
                    }
                }
                
                // If no friends, complete immediately
                if self.friends.isEmpty {
                    completion()
                }
            }
        }
    }
    
    private func fetchFriendReviewedPlaces(friend: User, completion: @escaping () -> Void) {
        firestoreService.fetchUserReviewPlaces(userId: friend.id, user: friend) { [weak self] places, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                if let places = places {
                    for place in places {
                        let placeId = place.id.uuidString
                        self.detailPlaceViewModel.places[placeId] = place
                        self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: friend)
                        // Add to placeSaversByPlace dictionary
                        self.placeSaversByPlace[placeId, default: []].append(friend)
                        self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                        self.updatePlaceAnnotationImages(for: placeId)
                    }
                }
                completion()
            }
        }
    }
    
    private func loadUserProfilePhoto(from urlString: String, forUserId userId: String, completion: @escaping () -> Void) {
        guard let url = URL(string: urlString) else {
            self.userProfilePhotos[userId] = nil
            completion()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                if let error = error {
                    print("Error loading profile photo: \(error)")
                    self.userProfilePhotos[userId] = nil
                    completion()
                    return
                }
                
                if let data = data, let image = UIImage(data: data) {
                    // Crop the image to a square before storing
                    let squareImage = self.cropToSquare(image)
                    self.userProfilePhotos[userId] = squareImage
                    
                    // If this is the current user's profile photo, update the main profile photo
                    if userId == self.userId {
                        self.profilePhotoImage = squareImage
                        self.profilePhoto = Image(uiImage: squareImage)
                    }
                } else {
                    self.userProfilePhotos[userId] = nil
                }
                completion()
            }
        }.resume()
    }
    
    
    // New function to process all followed users and their places
    func processFollowedUsersAndPlaces(completion: @escaping () -> Void) {
        firestoreService.fetchFollowingProfiles(for: userId) { [weak self] profiles, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                self.friends = profiles ?? []
                
                // First make sure current user profile photo is loaded
                let initialPhotoDispatchGroup = DispatchGroup()
                if let currentUser = self.currentUser {
                    initialPhotoDispatchGroup.enter()
                    if let photoURL = currentUser.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: currentUser.id) {
                            initialPhotoDispatchGroup.leave()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.userProfilePhotos[currentUser.id] = UIImage(named: "defaultProfile")
                            initialPhotoDispatchGroup.leave()
                        }
                    }
                }
                
                // Load profile photos for all friends first
                for friend in self.friends {
                    initialPhotoDispatchGroup.enter()
                    if let photoURL = friend.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: friend.id) {
                            initialPhotoDispatchGroup.leave()
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.userProfilePhotos[friend.id] = UIImage(named: "defaultProfile")
                            initialPhotoDispatchGroup.leave()
                        }
                    }
                }
                
                // After all profile photos are pre-loaded, proceed with fetching places
                initialPhotoDispatchGroup.notify(queue: .main) {
                    // If no friends, complete directly
                    guard !self.friends.isEmpty else { completion(); return }
                    
                    let dispatchGroup = DispatchGroup()
                    var processedPlaces = Set<String>()
                    
                    // Process each friend
                    for friend in self.friends {
                        // Load favorite places
                        dispatchGroup.enter()
                        self.firestoreService.fetchProfileFavorites(userId: friend.id) { [weak self] places in
                            guard let self = self else { dispatchGroup.leave(); return }
                            
                            DispatchQueue.main.async {
                                for place in places ?? [] {
                                    let placeId = place.id.uuidString
                                    processedPlaces.insert(placeId)
                                    // Store the place in the DetailPlaceViewModel
                                    self.detailPlaceViewModel.places[placeId] = place
                                    // Add user to place savers map
                                    self.placeSaversByPlace[placeId, default: []].append(friend)
                                    // Update in DetailPlaceViewModel for consistency
                                    self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: friend)
                                    // Fetch the place image
                                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                                }
                                dispatchGroup.leave()
                            }
                        }
                        
                        // Load placelists and their places
                        dispatchGroup.enter()
                        self.firestoreService.fetchLists(userId: friend.id) { [weak self] lists in
                            guard let self = self else { dispatchGroup.leave(); return }
                            
                            let listDispatchGroup = DispatchGroup()
                            guard !lists.isEmpty else { dispatchGroup.leave(); return }
                            
                            for list in lists {
                                listDispatchGroup.enter()
                                self.fetchFirestorePlaces(for: list.places) { detailPlaces in
                                    DispatchQueue.main.async {
                                        for place in detailPlaces {
                                            let placeId = place.id.uuidString
                                            processedPlaces.insert(placeId)
                                            // Store the place
                                            self.detailPlaceViewModel.places[placeId] = place
                                            // Add user to place savers map
                                            self.placeSaversByPlace[placeId, default: []].append(friend)
                                            // Update in DetailPlaceViewModel
                                            self.detailPlaceViewModel.updatePlaceSavers(placeId: placeId, user: friend)
                                            // Fetch the place image
                                            self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                                        }
                                        listDispatchGroup.leave()
                                    }
                                }
                            }
                            
                            listDispatchGroup.notify(queue: .main) {
                                dispatchGroup.leave()
                            }
                        }
                    }
                    
                    // First notify to collect all places
                    dispatchGroup.notify(queue: .main) {
                        // After all places are fetched, process annotation images
                        let finalProcessDispatchGroup = DispatchGroup()
                        
                        if processedPlaces.isEmpty {
                            // No places, just finish
                            completion()
                            return
                        }
                        
                        // Process annotation images for all collected places
                        for placeId in processedPlaces {
                            finalProcessDispatchGroup.enter()
                            // Generate the annotation image (profile photos are already loaded)
                            if let users = self.detailPlaceViewModel.placeSavers[placeId], !users.isEmpty {
                                let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                                self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                            } else {
                                // No users have saved this place, create a default annotation
                                let defaultImage = self.combinedCircularImage(image1: UIImage(named: "defaultProfile"))
                                self.placeAnnotationImages[placeId] = defaultImage
                            }
                            finalProcessDispatchGroup.leave()
                        }
                        
                        // After all annotation images are processed, call the completion handler
                        finalProcessDispatchGroup.notify(queue: .main) {
                            print("All place annotation images processed: \(self.placeAnnotationImages.count)")
                            completion()
                        }
                    }
                }
            }
        }
    }
}
