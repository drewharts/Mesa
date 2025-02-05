//
//  ProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/12/24.
//


import SwiftUI
import Combine
import GooglePlaces

class ProfileViewModel: ObservableObject {
    @Published var data: ProfileData
    @Published var placeListViewModels: [PlaceListViewModel] = []
    
    //lists new implementation
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [GMSPlace]] = [:] // Store places per list
    @Published var listImages: [UUID: UIImage] = [:]
    
    //favorite places new implementation
    @Published var userFavorites: [GMSPlace] = []
    @Published var placeImages: [String: UIImage] = [:] // Store images by placeID
    
    @Published var favoritePlaceViewModels: [PlaceViewModel] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]
    @Published var profilePhoto: Image? = nil
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
    public let userId: String
    private let googlePlacesService = GooglePlacesService()
    
    @Published var showMaxFavoritesAlert: Bool = false
    
    init(data: ProfileData, firestoreService: FirestoreService, userId: String) {
        self.data = data
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
        if let url = data.profilePhotoURL {
            loadImage(from: url)
        }
        fetchProfileFavorites(userId: userId)
        fetchLists(userId: userId)
        
    }
    func isPlaceInList(listId: UUID, placeId: String) -> Bool {
        guard let places = placeListGMSPlaces[listId] else {
            return false
        }
        return places.contains { $0.placeID == placeId }
    }
    
    func addPlaceToList(listId: UUID, place: GMSPlace ) {
        placeListGMSPlaces[listId, default: []].append(place)
    }
    
    func removePlaceFromList(listId: UUID, place: GMSPlace) {
        if var places = placeListGMSPlaces[listId] {
            places.removeAll {
                $0.placeID == place.placeID
            }
                    
            placeListGMSPlaces[listId] = places
        }
    }
    
    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
                self.userLists = lists
                
                // For each list, fetch its image and any other related data
                for list in lists {
                    self.fetchListImage(for: list)
                    self.fetchGMSPlaces(for: list.places) { gmsPlaces in
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
    
    func loadPhoto(for placeID: String) {
        googlePlacesService.fetchPhoto(placeID: placeID) { [weak self] image in
            DispatchQueue.main.async {
                self?.favoritePlaceImages[placeID] = image
            }
        }
    }
    
    func addFavoritePlace(prediction: GMSAutocompletePrediction) {
        // 1) If 4 favorites exist, show alert
        guard userFavorites.count < 4 else {
            showMaxFavoritesAlert = true
            return
        }
        
        googlePlacesService.fetchPlace(placeID: prediction.placeID) { [weak self] gmsPlace, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching place: \(error.localizedDescription)")
                return
            }
            guard let gmsPlace = gmsPlace else {
                print("No GMSPlace found for the given prediction")
                return
            }
            
            // 4) Add the place to local state + Firestore.
            self.addFavoritePlace(place: gmsPlace)
        }
    }
    
    // Appends the place to local state and Firestore, and initializes FavoritePlaceViewModel
    func addFavoritePlace(place: GMSPlace) {
        //        let favoritePlaceVM = PlaceViewModel(place: place)
        //        favoritePlaceViewModels.append(favoritePlaceVM)
        //        firestoreService.addProfileFavorite(userId: userId, place: place)
        userFavorites.append(place)
        let newPlace = Place(
            id: place.placeID!, name: place.name!, address: place.formattedAddress!
        )
        firestoreService.addProfileFavorite(userId: userId, place: newPlace)
    }
    
    func removeFavoritePlace(place: GMSPlace) {
        // Find the FavoritePlaceViewModel
        //        if let index = favoritePlaceViewModels.firstIndex(where: { $0.id == place.id }) {
        //            favoritePlaceViewModels.remove(at: index)
        //            firestoreService.removeProfileFavorite(userId: userId, placeId: place.id)
        //        }
        if let index = userFavorites.firstIndex(where: { $0.placeID == place.placeID }) {
            userFavorites.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: place.placeID!)
        }
    }
    
    func numberOfFavoritePlaces() -> Int {
        return favoritePlaceViewModels.count
    }
    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
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
    
    private func fetchPhoto(for place: GMSPlace) {
        guard let placeID = place.placeID else { return }
        if placeImages[placeID] != nil { return } // Avoid redundant fetching
        
        googlePlacesService.fetchPhoto(placeID: placeID) { image in
            DispatchQueue.main.async {
                self.placeImages[placeID] = image
            }
        }
    }
    
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
                // Map fetched Places to FavoritePlaceViewModel
                self.favoritePlaceViewModels = fetchedPlaces.map { place in
                    PlaceViewModel(place: place)
                }
            }
        }
    }
    
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self?.profilePhoto = Image(uiImage: uiImage)
            }
        }.resume()
    }
    
    func addNewPlaceList(named name: String, city: String, emoji: String, image: String) {
        let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image)
        //        let placeListViewModel = PlaceListViewModel(placeList: newPlaceList, firestoreService: firestoreService, userId: userId)
        
        //        placeListViewModels.append(placeListViewModel)
        userLists.append(newPlaceList)
        firestoreService.createNewList(placeList: newPlaceList, userID: userId)
    }
    
    func removePlaceList(placeList: PlaceList) {
        if let index = userLists.firstIndex(where: { $0.id == placeList.id }) {
            // Remove from local array
            userLists.remove(at: index)
            firestoreService.deleteList(userId: self.userId, listName: placeList.name) { error in
                if let error = error {
                    // Handle the error (for example, show an alert to the user)
                    print("Failed to delete list: \(error.localizedDescription)")
                } else {
                    // Successfully deleted list—update your local state if necessary.
                    if let index = self.userLists.firstIndex(where: { $0.id == placeList.id }) {
                        self.userLists.remove(at: index)
                    }
                }
            }
        }
    }
}
