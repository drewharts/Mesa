//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import SwiftUI
import GooglePlaces

struct ProfileData: Codable {
    var firstName: String
    var lastName: String
    var email: String
    var profilePhotoURL: URL?
    var phoneNumber: String
    var placeLists: [PlaceList]
}

class Profile: ObservableObject {
    @Published var data: ProfileData
    @Published var profilePhoto: Image? = nil  // Image stored separately
    weak var delegate: ProfileDelegate?
    private let firestoreService = FirestoreService()
    private let userId: String

    init(user: User, phoneNumber: String, userId: String) {
        self.userId = userId
        // Convert user + phoneNumber to ProfileData
        self.data = ProfileData(
            firstName: user.firstName,
            lastName: user.lastName,
            email: user.email,
            profilePhotoURL: user.profilePhotoURL,
            phoneNumber: phoneNumber,
            placeLists: []
        )
        loadPlaceListes()
        loadImage(from: data.profilePhotoURL!)
    }
    
    func loadPlaceListes() {
        firestoreService.fetchLists(userId: userId) { placeLists in
            self.data.placeLists = placeLists
        }
    }

    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.profilePhoto = Image(uiImage: uiImage)
            }
        }.resume()
    }

    func addPlaceToList(place: GMSPlace, listName: String = "Favorites") {
        if let list = data.placeLists.first(where: { $0.name == listName }) {
            if !list.places.contains(where: { $0.placeID == place.placeID }) {
                list.addPlace(place)
                firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
                delegate?.didAddPlace(toList: listName, place: place)
            }
        } else {
            let newList = PlaceList(name: listName)
            newList.addPlace(place)
            data.placeLists.append(newList)
            firestoreService.createNewList(userId: userId, listName: listName)
            firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
            delegate?.didAddPlace(toList: listName, place: place)
        }
    }
}
