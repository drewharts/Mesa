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
    @Published var favoritePlaceViewModels: [FavoritePlaceViewModel] = []
    @Published var favoritePlaceImages: [String: UIImage] = [:]
    @Published var profilePhoto: Image? = nil
    weak var delegate: ProfileDelegate?
    private let firestoreService: FirestoreService
    private let userId: String
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
    }
    
    func getUserId() -> String {
        return userId
    }

    func loadPhoto(for placeID: String) {
        googlePlacesService.fetchPhoto(placeID: placeID) { [weak self] image in
            DispatchQueue.main.async {
                self?.favoritePlaceImages[placeID] = image
            }
        }
    }

    // Adds a favorite place from a Google prediction
    func addFavoritePlace(prediction: GMSAutocompletePrediction) {
        // 1) If 4 favorites exist, show alert
        guard favoritePlaceViewModels.count < 4 else {
            showMaxFavoritesAlert = true
            return
        }

        // 2) Convert the prediction into a Place with placeholder coordinates
        let newPlace = Place(
            id: prediction.placeID ?? UUID().uuidString,
            name: prediction.attributedPrimaryText.string,
            address: prediction.attributedSecondaryText?.string ?? "Unknown Address"
        )

        // 3) Add the place to local + Firestore
        addFavoritePlace(place: newPlace)
    }

    // Appends the place to local state and Firestore, and initializes FavoritePlaceViewModel
    func addFavoritePlace(place: Place) {
        let favoritePlaceVM = FavoritePlaceViewModel(place: place)
        favoritePlaceViewModels.append(favoritePlaceVM)
        firestoreService.addProfileFavorite(userId: userId, place: place)
    }

    func removeFavoritePlace(place: Place) {
        // Find the FavoritePlaceViewModel
        if let index = favoritePlaceViewModels.firstIndex(where: { $0.id == place.id }) {
            favoritePlaceViewModels.remove(at: index)
            firestoreService.removeProfileFavorite(userId: userId, placeId: place.id)
        }
    }

    func numberOfFavoritePlaces() -> Int {
        return favoritePlaceViewModels.count
    }

    func getPlaceListViewModel(named name: String) -> PlaceListViewModel? {
        return placeListViewModels.first { $0.placeList.name == name }
    }

    func loadPlaceLists() {
        // Fetch profile lists
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.data.placeLists = placeLists
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
                    FavoritePlaceViewModel(place: place)
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
        let placeListViewModel = PlaceListViewModel(placeList: newPlaceList, firestoreService: firestoreService, userId: userId)

        placeListViewModels.append(placeListViewModel)
        data.placeLists.append(newPlaceList)

        firestoreService.createNewList(placeList: newPlaceList, userID: userId)
    }

    func removePlaceList(at index: Int) {
        guard placeListViewModels.indices.contains(index) else { return }
        let placeListVM = placeListViewModels.remove(at: index)
        //TODO: Implement this remove list from firestore
//        firestoreService.removeList(userId: userId, listName: placeListVM.placeList.name)
        data.placeLists.removeAll { $0.id == placeListVM.placeList.id }
    }
}
