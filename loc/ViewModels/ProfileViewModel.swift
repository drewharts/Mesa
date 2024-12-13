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
    @Published var profilePhoto: Image? = nil
    weak var delegate: ProfileDelegate?
    private let firestoreService = FirestoreService()
    private let userId: String

    init(data: ProfileData, userId: String) {
        self.data = data
        self.userId = userId
        loadPlaceLists()
        if let url = data.profilePhotoURL {
            loadImage(from: url)
        }
    }

    func loadPlaceLists() {
        firestoreService.fetchLists(userId: userId) { [weak self] placeLists in
            self?.data.placeLists = placeLists
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

    func addPlaceToList(place: GMSPlace, listName: String = "Favorites") {
        let placeCity = place.addressComponents?.first(where: { $0.types.contains("locality") })?.name ?? ""
        if let listIndex = data.placeLists.firstIndex(where: { $0.name == listName }) {
            let list = data.placeLists[listIndex]
            if !list.places.contains(where: { $0.placeID == place.placeID }) {
                data.placeLists[listIndex].addPlace(place)
                firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
                delegate?.didAddPlace(toList: listName, place: place)
            }
        } else {
            var newList = PlaceList(name: listName, city: placeCity)
            newList.addPlace(place)
            data.placeLists.append(newList)
            firestoreService.createNewList(userId: userId, listName: listName, city: placeCity)
            firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
            delegate?.didAddPlace(toList: listName, place: place)
        }
    }
}
