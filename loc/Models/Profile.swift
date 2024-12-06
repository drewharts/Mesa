//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import SwiftUI
import GooglePlaces

class Profile: ObservableObject {
    @Published var firstName: String
    @Published var lastName: String
    @Published var email: String
    @Published var profilePhoto: Image? = nil
    @Published var phoneNumber: String
    @Published var placeLists: [PlaceList] = []

    weak var delegate: ProfileDelegate?
    private let firestoreService = FirestoreService()
    private let userId: String // User's unique Firestore ID

    init(user: User, phoneNumber: String, userId: String) {
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.email = user.email
        self.phoneNumber = phoneNumber
        self.userId = userId

        if let url = user.profilePhotoURL {
            loadImage(from: url)
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
        if let list = placeLists.first(where: { $0.name == listName }) {
            if !list.places.contains(where: { $0.placeID == place.placeID }) {
                list.addPlace(place)
                firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
                delegate?.didAddPlace(toList: listName, place: place)
            }
        } else {
            let newList = PlaceList(name: listName)
            newList.addPlace(place)
            placeLists.append(newList)
            firestoreService.createNewList(userId: userId, listName: listName)
            firestoreService.addPlaceToList(userId: userId, listName: listName, place: place)
            delegate?.didAddPlace(toList: listName, place: place)
        }
    }
}
