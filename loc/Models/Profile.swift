//
//  Profile.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import Foundation
import SwiftUI

class Profile {
    var firstName: String
    var lastName: String
    var email: String
    var profilePhoto: Image? = nil
    var phoneNumber: String
    var placeLists: [PlaceList] = []
    
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
        // For simplicity, here's a basic example using URLSession
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
}
