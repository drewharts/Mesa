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
    
    init(user: User, phoneNumber: String) {
        self.firstName = user.firstName
        self.lastName = user.lastName
        self.email = user.email
        self.phoneNumber = phoneNumber
        
        if let url = user.profilePhotoURL {
            loadImage(from: url)
        }
    }
    
    private func loadImage(from url: URL) {
        // Asynchronously load the image from the URL
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let uiImage = UIImage(data: data) else { return }
            DispatchQueue.main.async {
                self.profilePhoto = Image(uiImage: uiImage)
            }
        }.resume()
    }
    
    func addPlacesList(_ placeList: PlaceList) {
        placeLists.append(placeList)
    }
    
    func removePlacesList(named name: String) {
        placeLists.removeAll { $0.name == name }
    }
    
    func addPlaceToList(place: GMSPlace, listName: String = "Favorites") {
        if let list = placeLists.first(where: { $0.name == listName }) {
            if !list.places.contains(where: { $0.placeID == place.placeID }) {
                list.addPlace(place)
            }
        } else {
            let newList = PlaceList(name: listName)
            newList.addPlace(place)
            placeLists.append(newList)
        }
    }
    
    func addPlace(place: GMSPlace, to list: PlaceList) {
        if !list.places.contains(where: { $0.placeID == place.placeID }) {
            list.addPlace(place)
        }
    }
}
