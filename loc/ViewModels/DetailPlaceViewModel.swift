//
//  DetailPlaceViewModel.swift
//  loc
//
//  Created by Andrew Hartsfield II on 3/22/25.
//

import Foundation
import UIKit
import FirebaseFirestore
import MapboxSearch
import FirebaseAuth


class DetailPlaceViewModel: ObservableObject {
    @Published var places: [String: DetailPlace] = [:] // Formerly placeLookup
    @Published var placeImages: [String: UIImage] = [:] // Consolidated place images
    @Published var placeSavers: [String: [String]] = [:] // Tracks who saved each place PlaceId -> UserIds
    @Published var placeTypes: [String: String] = [:] // Tracks restaurant types

    @Published var userProfilePicture: [String: UIImage] = [:] // Each user's profile picture

    private let firestoreService: FirestoreService
    private var notificationObserver: NSObjectProtocol?
    private let placeDetailVM = PlaceDetailViewModel() // For restaurant type calculation

    init(firestoreService: FirestoreService) {
        self.firestoreService = firestoreService
        
        // Add observer for map refresh notifications
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("RefreshMapAnnotations"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            print("DetailPlaceViewModel received map refresh notification")
            // Force a refresh by triggering objectWillChange
            self.objectWillChange.send()
        }
    }
    
    deinit {
        // Remove observer when this view model is deallocated
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Calculate and store restaurant type
    private func calculateRestaurantType(for place: DetailPlace) {
        let placeId = place.id.uuidString
        if let type = placeDetailVM.getRestaurantType(for: place) {
            placeTypes[placeId] = type
        }
    }

    // Fetch place data (e.g., from Firestore)
    func fetchPlaceDetails(placeId: String, completion: @escaping (DetailPlace?) -> Void) {
        firestoreService.fetchPlace(withId: placeId) { [weak self] result in
            guard let self = self else {
                completion(nil)
                return
            }
            switch result {
            case .success(let detailPlace):
                DispatchQueue.main.async {
                    self.places[placeId] = detailPlace
                    self.fetchPlaceImage(for: placeId) // Fetch image if not already present
                    self.calculateRestaurantType(for: detailPlace) // Calculate restaurant type
                    completion(detailPlace)
                }
            case .failure(let error):
                print("Error fetching place \(placeId): \(error.localizedDescription)")
                completion(nil)
            }
        }
    }

    func fetchPlaceImage(for placeId: String) {
        guard placeImages[placeId] == nil else { return }
        
        // Get the current user ID
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("Error: Current user ID is not available")
            DispatchQueue.main.async {
                self.placeImages[placeId] = nil
            }
            return
        }
        
        // Use friends' reviews to get images (both restaurant and generic)
        firestoreService.fetchFriendsReviews(placeId: placeId, currentUserId: currentUserId) { [weak self] (reviews, error) in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching reviews for place \(placeId): \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.placeImages[placeId] = nil
                }
                return
            }
            if let reviews = reviews {
                var imageURLs: [URL] = []
                for review in reviews {
                    for urlString in review.images {
                        if let url = URL(string: urlString) {
                            imageURLs.append(url)
                        }
                    }
                }
                self.downloadFirstSuccessfulImage(from: imageURLs, for: placeId)
            } else {
                DispatchQueue.main.async {
                    self.placeImages[placeId] = nil
                }
            }
        }
    }

    private func downloadFirstSuccessfulImage(from urls: [URL], for placeId: String) {
        guard !urls.isEmpty else {
            DispatchQueue.main.async {
                self.placeImages[placeId] = nil
            }
            return
        }
        let url = urls[0]
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.placeImages[placeId] = image
                }
            } else {
                // Try the next URL if this one fails
                let remainingURLs = Array(urls.dropFirst())
                self.downloadFirstSuccessfulImage(from: remainingURLs, for: placeId)
            }
        }.resume()
    }

    // Update placeSavers when a user saves a place
    func updatePlaceSavers(placeId: String, user: User) {
        print("fix later")
//        if placeSavers[placeId] != nil {
//            if !placeSavers[placeId]!.contains(where: { $0.id == user.id }) {
//                placeSavers[placeId]!.append(user)
//            }
//        } else {
//            placeSavers[placeId] = [user]
//        }
    }

    // Convert SearchResult to DetailPlace and save it
    func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        // Safely unwrap mapboxId to avoid force-unwrap crash
        guard let mapboxId = place.mapboxId else {
            print("SearchResult has no mapboxId")
            return
        }
        
        firestoreService.findPlace(mapboxId: mapboxId) { [weak self] existingDetailPlace, error in
            guard let self = self else { return }
            
            // Log any errors from Firestore lookup
            if let error = error {
                print("Error checking for existing place: \(error.localizedDescription)")
            }
            
            // If place exists, return it
            if let existingDetailPlace = existingDetailPlace {
                // Calculate restaurant type for existing place
                self.calculateRestaurantType(for: existingDetailPlace)
                completion(existingDetailPlace)
                return
            }
            
            // Create new DetailPlace using the new constructor
            let detailPlace = DetailPlace(from: place)
            
            // Update local state and fetch image on main thread
            DispatchQueue.main.async {
                self.places[detailPlace.id.uuidString] = detailPlace
                self.fetchPlaceImage(for: detailPlace.id.uuidString)
                self.calculateRestaurantType(for: detailPlace) // Calculate restaurant type
                completion(detailPlace)
            }
        }
    }
}
