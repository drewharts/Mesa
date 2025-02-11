//
//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//

import SwiftUI
import Combine
import GooglePlaces
import MapboxSearch

class ProfileViewModel: ObservableObject {
    @Published var data: ProfileData
    @Published var placeListViewModels: [PlaceListViewModel] = []
    
    // Lists new implementation
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [SearchResult]] = [:] // Store places per list
    @Published var listImages: [UUID: UIImage] = [:]
    
    // Favorite places new implementation
    @Published var userFavorites: [SearchResult] = []
    @Published var placeImages: [String: UIImage] = [:] // Store images by placeID
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]
    @Published var profilePhoto: SwiftUI.Image? = nil
    
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
    public let userId: String
    // private let googlePlacesService = GooglePlacesService()
    private let mapboxSearchService = MapboxSearchService()
    
    @Published var showMaxFavoritesAlert: Bool = false
    
    // MARK: - Initializer
    
    init(data: ProfileData, firestoreService: FirestoreService, userId: String) {
        self.data = data
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
        if let url = data.profilePhotoURL {
            loadImage(from: url)
        }
        // Uncomment if needed: fetchProfileFavorites(userId: userId)
        fetchLists(userId: userId)
    }
    
    // MARK: - Place List Management
    
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let places = placeListGMSPlaces[listId] else {
            return false
        }
        return places.contains { $0.id == placeId }
    }
    
    func addPlaceToList(listId: UUID, place: SearchResult) {
        let newPlace = Place(
            name: place.name,
            address: place.address?.formattedAddress(style: .medium) ?? ""
        )
        
        placeListGMSPlaces[listId, default: []].append(place)
        
        firestoreService.addPlaceToList(userId: userId, listName: listId.uuidString, place: newPlace)
        
        let detailPlace = DetailPlace(place: newPlace)
        
        firestoreService.addToAllPlaces(detailPlace: detailPlace) { error in
            if let error = error {
                print("Error adding place: \(error.localizedDescription)")
            } else {
                print("Place added successfully!")
            }
        }
    }
    
    func removePlaceFromList(listId: UUID, place: SearchResult) {
        if var places = placeListGMSPlaces[listId] {
            places.removeAll { $0.id == place.id }
            placeListGMSPlaces[listId] = places
        }
        firestoreService.removePlaceFromList(userId: userId, listName: listId.uuidString, placeId: place.id)
    }
    
    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
                self.userLists = lists
                
                // For each list, fetch its image and any other related data
                for list in lists {
                    self.fetchListImage(for: list)
                    self.fetchMapboxPlaces(for: list.places) { gmsPlaces in
                        self.placeListGMSPlaces[list.id] = gmsPlaces
                    }
                }
            }
        }
    }
    
    private func fetchListImage(for list: PlaceList) {
        // Ensure the list has an image URL
        guard let imageUrlString = list.image, let url = URL(string: imageUrlString) else { return }
        
        // Check if the image is already cached
        if listImages[list.id] != nil { return }
        
        // Fetch the image
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self, let data = data, let image = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.listImages[list.id] = image
            }
        }.resume()
    }
    
    // MARK: - Favorite Places Management
    
    func addFavoritePlace(place: SearchResult) {
        // Append the place to local state and add to Firestore
        userFavorites.append(place)
        let newPlace = Place(
            id: place.id,
            name: place.name,
            address: place.address!.formattedAddress(style: .medium)!
        )
        firestoreService.addProfileFavorite(userId: userId, place: newPlace)
    }
    
    func removeFavoritePlace(place: SearchResult) {
        if let index = userFavorites.firstIndex(where: { $0.id == place.id }) {
            userFavorites.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: place.id)
        }
    }
    
    func numberOfFavoritePlaces() -> Int {
        return favoritePlaceViewModels.count
    }
    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
    }
    
    // MARK: - Mapbox Search
    
    func fetchMapboxPlaces(for places: [Place], completion: @escaping ([SearchResult]) -> Void) {
        var fetchedPlaces: [SearchResult] = []
        let dispatchGroup = DispatchGroup()
        
        for place in places {
            dispatchGroup.enter()
            
            mapboxSearchService.searchPlaces(query: place.name,
                                             onResultsUpdated: { results in
                if let firstResult = results.first {
                    fetchedPlaces.append(firstResult)
                }
                dispatchGroup.leave()
            },
                                             onError: { error in
                print("Error fetching place from Mapbox: \(error)")
                dispatchGroup.leave()
            })
        }
        
        dispatchGroup.notify(queue: .main) {
            DispatchQueue.main.async {
                completion(fetchedPlaces)
            }
        }
    }
    
    // MARK: - Loading Data
    
    func loadPlaceLists() {
        // Fetch profile lists
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.placeListViewModels = placeLists.map { placeList in
                    PlaceListViewModel(
                        placeList: placeList,
                        firestoreService: self.firestoreService,
                        userId: self.userId
                    )
                }
            }
        }
        
        // Fetch profile favorites
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] fetchedPlaces in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.favoritePlaceViewModels = fetchedPlaces.map { place in
                    PlaceViewModel(place: place)
                }
            }
        }
    }
    
    func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.profilePhoto = Image(uiImage: uiImage)
            }
        }.resume()
    }
    
    // MARK: - Place List Creation / Deletion
    
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
        let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
        userLists.append(newPlaceList)
        firestoreService.createNewList(placeList: newPlaceList, userID: userId)
    }
    
    func removePlaceList(placeList: PlaceList) {
        if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
            // Remove from local array
            userLists.remove(at: index)
            firestoreService.deleteList(userId: self.userId, listName: placeList.name) { error in
                if let error = error {
                    print("Failed to delete list: \(error.localizedDescription)")
                } else {
                    // Update local state if necessary
                    if let index = self.userLists.firstIndex(where: { $0.id == placeList.id }) {
                        self.userLists.remove(at: index)
                    }
                }
            }
        }
    }
}
