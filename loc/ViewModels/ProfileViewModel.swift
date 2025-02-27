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
import Foundation
import FirebaseFirestore


class ProfileViewModel: ObservableObject {
    @Published var data: ProfileData
    @Published var placeListViewModels: [PlaceListViewModel] = []
    
    // Lists new implementation
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [DetailPlace]] = [:] // Store places per list
    @Published var listImages: [UUID: UIImage] = [:]
    
    // Favorite places new implementation
    @Published var userFavorites: [DetailPlace] = []
    @Published var placeImages: [String: UIImage] = [:] // Store images by placeID
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]
    @Published var profilePhoto: SwiftUI.Image? = nil
    
    //followers and following
    @Published var followers: Int = 0
    
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
        fetchLists(userId: userId)
        fetchFavorites(userId: userId)
        fetchFollowers(userId: userId)
    }
    
    // MARK: - Place List Management
    func fetchFollowers(userId: String) {
        firestoreService.getNumberFollowers(forUserId: userId) { (count, error) in
            if let error = error {
                print("Error fetching followers: \(error.localizedDescription)")
                return
            }
            self.followers = count
        }
    }
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let places = placeListGMSPlaces[listId] else {
            return false
        }
        return places.contains { $0.id.uuidString == placeId }
    }
    
    func addPlaceToList(listId: UUID, place: DetailPlace) {
        let newPlace = Place(
            id: place.id,
            name: place.name,
            address: place.address!
        )
//        var detailPlace = searchResultToDetailPlace(place: place)
        
        placeListGMSPlaces[listId, default: []].append(place)
        
        firestoreService.addPlaceToList(userId: userId, listName: listId.uuidString, place: newPlace)
                
        firestoreService.addToAllPlaces(detailPlace: place) { error in
            if let error = error {
                print("Error adding place: \(error.localizedDescription)")
            } else {
                print("Place added successfully!")
            }
        }
    }
    
    private func searchResultToDetailPlace(place: SearchResult) -> DetailPlace {
        let uuid = UUID(uuidString: place.id) ?? UUID()

        var detailPlace = DetailPlace(id: uuid, name: place.name,address: place.address?.formattedAddress(style: .medium) ?? "")
        
        detailPlace.mapboxId = place.id
        detailPlace.coordinate = GeoPoint(
            latitude: Double(place.coordinate.latitude),
            longitude: Double(place.coordinate.longitude)
        )
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
        
        return detailPlace
        
    }
    
    func removePlaceFromList(listId: UUID, place: DetailPlace) {
        if var places = placeListGMSPlaces[listId] {
            places.removeAll { $0.id.uuidString == place.id.uuidString }
            placeListGMSPlaces[listId] = places
        }
        firestoreService.removePlaceFromList(userId: userId, listName: listId.uuidString, placeId: place.id.uuidString)
    }
    
    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
                self.userLists = lists
                
                // For each list, fetch its image and any other related data
                for list in lists {
                    self.fetchListImage(for: list)
                    self.fetchFirestorePlaces(for: list.places) { gmsPlaces in
                        self.placeListGMSPlaces[list.id] = gmsPlaces
                    }
                }
            }
        }
    }
    
    private func fetchFavorites(userId: String) {
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] favorites in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Update the userFavorites array with the fetched favorites
                self.userFavorites = favorites
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
    
//    func addFavoritePlace(place: DetailPlace) {
//        // Append the place to local state and add to Firestore
//        userFavorites.append(place)
//        
//        guard let uuid = UUID(uuidString: place.id.uuidString) else {
//            print("Invalid UUID string: \(place.id)")
//            return
//        }
//        
//        let newPlace = Place(
//            id: uuid,
//            name: place.name,
//            address: place.address!
//        )
//        firestoreService.addProfileFavorite(userId: userId, place: newPlace)
//    }
    
    func removeFavoritePlace(place: DetailPlace) {
        if let index = userFavorites.firstIndex(where: { $0.id.uuidString == place.id.uuidString }) {
            userFavorites.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: place.id.uuidString)
        }
    }
    
    func addFavoriteFromSuggestion(_ suggestion: SearchSuggestion) {
        print("🔍 User selected suggestion: \(suggestion.id) - \(suggestion.name)")
        
        // Resolve the suggestion to a SearchResult using your Mapbox search service.
        mapboxSearchService.selectSuggestion(suggestion) { [weak self] result in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                print("✅ Resolved result: \(result.id) - \(result.name)")
                
                // Convert the SearchResult into a DetailPlace.
                let detailPlace = self.searchResultToDetailPlace(place: result)
                
                // Add the DetailPlace to the favorites.
                self.userFavorites.append(detailPlace)

                self.firestoreService.addProfileFavorite(userId: self.userId, place: detailPlace)

            }
        }
    }
    
    func numberOfFavoritePlaces() -> Int {
        return favoritePlaceViewModels.count
    }
    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
    }
    
    // MARK: - Mapbox Search
    
    func fetchFirestorePlaces(for places: [Place], completion: @escaping ([DetailPlace]) -> Void) {
        var fetchedPlaces: [DetailPlace] = []
        let dispatchGroup = DispatchGroup()
        
        for place in places {
            dispatchGroup.enter()
            
            // Convert the UUID to a String since Firestore expects document IDs as Strings.
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
//        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] fetchedPlaces in
//            guard let self = self else { return }
//            DispatchQueue.main.async {
//                self.favoritePlaceViewModels = fetchedPlaces.map { place in
//                    PlaceViewModel(place: place)
//                }
//            }
//        }
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
