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
    @Published var placeListMBPlaces: [UUID: [String]] = [:] // Now stores place IDs
    @Published var listImages: [UUID: UIImage] = [:]
    
    @Published var userFavorites: [String] = [] // Now stores place IDs
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var profilePhoto: SwiftUI.Image? = nil
    @Published var profilePhotoImage: UIImage? = nil
    @Published private var userProfilePhotos: [String: UIImage] = [:]

    @Published var friends: [User] = []
    @Published var followers: Int = 0
    @Published var following: Int = 0
    
    @Published var placeAnnotationImages: [String: UIImage] = [:] // Still here for now
    
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
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
        fetchFriends(userId: userId) {
            dispatchGroup.leave()
        }
        
        dispatchGroup.notify(queue: .main) {
            self.isLoading = false
        }
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
                            self.loadUserProfilePhoto(from: photoURL, forUserId: userId) {
                                self.fetchFriendFavPlaces(friend: userToFollow) {}
                                self.fetchAndProcessFriendLists(friend: userToFollow) {}
                            }
                        } else {
                            self.userProfilePhotos[userId] = nil
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
                    self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                    let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                    self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
                
                var pendingTasks = self.friends.count * 2
                for friend in self.friends {
                    if let photoURL = friend.profilePhotoURL {
                        self.loadUserProfilePhoto(from: photoURL, forUserId: friend.id) {
                            self.fetchFriendFavPlaces(friend: friend) { pendingTasks -= 1; if pendingTasks == 0 { completion() } }
                            self.fetchAndProcessFriendLists(friend: friend) { pendingTasks -= 1; if pendingTasks == 0 { completion() } }
                        }
                    } else {
                        self.userProfilePhotos[friend.id] = nil
                        self.fetchFriendFavPlaces(friend: friend) { pendingTasks -= 1; if pendingTasks == 0 { completion() } }
                        self.fetchAndProcessFriendLists(friend: friend) { pendingTasks -= 1; if pendingTasks == 0 { completion() } }
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
                    let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                    self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
                }
                completion()
            }
        }
    }
    
    func getAllDetailPlaces() -> [DetailPlace] {
        detailPlaceViewModel.places.values.map { $0 }
    }
    
    public func getFirstThreeProfileImages(forKey key: String) -> (UIImage?, UIImage?, UIImage?) {
        guard let users = detailPlaceViewModel.placeSavers[key] else {
            print("No users found for place ID: \(key)")
            return (nil, nil, nil)
        }
        let firstThreeUsers = users.prefix(3)
        let images = firstThreeUsers.map { self.userProfilePhotos[$0.id] ?? UIImage(named: "defaultProfile") }
        let paddedImages = (images + [nil, nil, nil]).prefix(3)
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
                context.cgContext.restoreGState()
            }
            
            if image3 != nil { drawCircularImage(image3, in: thirdRect) }
            if image2 != nil { drawCircularImage(image2, in: secondRect) }
            drawCircularImage(image1 ?? UIImage(named: "DestPin")!, in: firstRect)
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
                }
                self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
        // No need to update placeSavers here; DetailPlaceViewModel handles it if needed
        let (image1, image2, image3) = getFirstThreeProfileImages(forKey: placeId)
        placeAnnotationImages[placeId] = combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
                        let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                        self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
                                self.detailPlaceViewModel.fetchPlaceImage(for: placeId)
                                let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                                self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
                    let (image1, image2, image3) = self.getFirstThreeProfileImages(forKey: placeId)
                    self.placeAnnotationImages[placeId] = self.combinedCircularImage(image1: image1, image2: image2, image3: image3)
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
    private func loadUserProfilePhoto(from url: URL, forUserId userId: String, completion: (() -> Void)? = nil) {
        if userProfilePhotos[userId] != nil { completion?(); return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { completion?(); return }
            DispatchQueue.main.async {
                self.userProfilePhotos[userId] = data.flatMap { UIImage(data: $0) }
                completion?()
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
}
