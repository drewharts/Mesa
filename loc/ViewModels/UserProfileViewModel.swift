//
//  UserProfileViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import Foundation
import GooglePlaces
import UIKit

class UserProfileViewModel: ObservableObject {
    @Published var selectedUser: ProfileData?
    @Published var isUserDetailPresented = false
    
    @Published var userFavorites: [GMSPlace] = []
    @Published var userLists: [PlaceList] = []
    @Published var placeListGMSPlaces: [UUID: [GMSPlace]] = [:] // Store places per list
    @Published var placeImages: [String: UIImage] = [:] // Store images by placeID

    private let firestoreService = FirestoreService()
    private let googlePlacesService = GooglePlacesService()

    func selectUser(_ user: ProfileData) {
        DispatchQueue.main.async {
            self.selectedUser = user
            self.isUserDetailPresented = true
        }
        
        fetchProfileFavorites(userId: user.id)
        fetchLists(userId: user.id)
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

    private func fetchLists(userId: String) {
        firestoreService.fetchLists(userId: userId) { lists in
            DispatchQueue.main.async {
                self.userLists = lists
                
                // Fetch GMSPlaces for each PlaceList
                for list in lists {
                    self.fetchGMSPlaces(for: list.places) { gmsPlaces in
                        self.placeListGMSPlaces[list.id] = gmsPlaces
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
    
    /// Fetches a photo for a given `GMSPlace` and stores it in `placeImages`
    private func fetchPhoto(for place: GMSPlace) {
        guard let placeID = place.placeID else { return }
        if placeImages[placeID] != nil { return } // Avoid redundant fetching
        
        googlePlacesService.fetchPhoto(placeID: placeID) { image in
            DispatchQueue.main.async {
                self.placeImages[placeID] = image
            }
        }
    }
}
