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
    @Published var favoritePlaces: [Place] = []
    @Published var profilePhoto: Image? = nil
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
    private let userId: String
    
    @Published var showMaxFavoritesAlert: Bool = false

    init(data: ProfileData, firestoreService: FirestoreService, userId: String) {
        self.data = data
        self.firestoreService = firestoreService
        self.userId = userId
        loadPlaceLists()
        if let url = data.profilePhotoURL {
            loadImage(from: url)
        }
    }
    
    // Converts prediction -> Place, then adds it.
    func addFavoritePlace(prediction: GMSAutocompletePrediction) {
        // 1) If 4 favorites exist, do nothing (or show a message, etc.)
        guard favoritePlaces.count < 4 else {
            // You could display an alert or some UI feedback if you like
            showMaxFavoritesAlert = true
            return
        }
        
        // 2) Convert the prediction into a Place
        let newPlace = Place(
            id: prediction.placeID ?? UUID().uuidString,
            name: prediction.attributedPrimaryText.string,
            address: prediction.attributedSecondaryText?.string ?? "Unknown"
        )
        
        // 3) Add the place to local + Firestore
        addFavoritePlace(place: newPlace)
    }

    
    // Actually appends the place to local state and Firestore.
    func addFavoritePlace(place: Place) {
        favoritePlaces.append(place)
        firestoreService.addProfileFavorite(userId: userId, place: place)
    }
    
    func numberOfFavoritePlaces() -> Int {
        return favoritePlaces.count
    }

    
    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
    }

    func loadPlaceLists() {
        //fetch profile lists
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            self?.data.placeLists = placeLists
            self?.placeListViewModels = placeLists.map { PlaceListViewModel(placeList: $0,firestoreService: self!.firestoreService, userId: self!.userId) }
        }
        //fetch profile favorites
        firestoreService.fetchProfileFavorites(userId: userId) { [weak self] fetchedPlaces in
            self?.favoritePlaces = fetchedPlaces
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
        let newPlaceList = PlaceList(name: name, city: city, emoji: emoji, image: image);
        let placeListViewModel = PlaceListViewModel(placeList: newPlaceList,firestoreService: firestoreService, userId: userId)
        placeListViewModels.append(placeListViewModel)
        data.placeLists.append(newPlaceList)
        
        firestoreService.createNewList(placeList: newPlaceList, userID: userId)
    }
    
    func removePlaceList(at index: Int) {
        guard placeListViewModels.indices.contains(index) else { return }
        placeListViewModels.remove(at: index)
    }
}
