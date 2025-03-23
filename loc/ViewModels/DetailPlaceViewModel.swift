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


class DetailPlaceViewModel: ObservableObject {
    @Published var places: [String: DetailPlace] = [:] // Formerly placeLookup
    @Published var placeImages: [String: UIImage] = [:] // Consolidated place images
    @Published var placeSavers: [String: [User]] = [:] // Tracks who saved each place

    private let firestoreService: FirestoreService

    init(firestoreService: FirestoreService) {
        self.firestoreService = firestoreService
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
        firestoreService.fetchReviews(placeId: placeId, latestOnly: false) { [weak self] (reviews, error) in
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
        if placeSavers[placeId] != nil {
            if !placeSavers[placeId]!.contains(where: { $0.id == user.id }) {
                placeSavers[placeId]!.append(user)
            }
        } else {
            placeSavers[placeId] = [user]
        }
    }

    // Convert SearchResult to DetailPlace and save it
    func searchResultToDetailPlace(place: SearchResult, completion: @escaping (DetailPlace) -> Void) {
        firestoreService.findPlace(mapboxId: place.mapboxId!) { [weak self] existingDetailPlace, error in
            guard let self = self else { return }
            if let error = error {
                print("Error checking for existing place: \(error.localizedDescription)")
            }
            if let existingDetailPlace = existingDetailPlace {
                completion(existingDetailPlace)
                return
            }
            let uuid = UUID(uuidString: place.id) ?? UUID()
            var detailPlace = DetailPlace(id: uuid, name: place.name, address: place.address?.formattedAddress(style: .medium) ?? "", city: place.address?.place ?? "")
            detailPlace.mapboxId = place.mapboxId
            detailPlace.coordinate = GeoPoint(latitude: Double(place.coordinate.latitude), longitude: Double(place.coordinate.longitude))
            detailPlace.categories = place.categories
            detailPlace.phone = place.metadata?.phone
            detailPlace.rating = place.metadata?.rating ?? 0
            detailPlace.description = place.metadata?.description ?? ""
            detailPlace.priceLevel = place.metadata?.priceLevel
            detailPlace.reservable = place.metadata?.reservable ?? false
            detailPlace.servesBreakfast = place.metadata?.servesBreakfast ?? false
            detailPlace.serversLunch = place.metadata?.servesLunch ?? false
            detailPlace.serversDinner = place.metadata?.servesDinner ?? false
            detailPlace.Instagram = place.metadata?.instagram
            detailPlace.X = place.metadata?.twitter
            self.firestoreService.addToAllPlaces(detailPlace: detailPlace) { error in
                if let error = error {
                    print("Error saving new place to Firestore: \(error.localizedDescription)")
                }
                DispatchQueue.main.async {
                    self.places[detailPlace.id.uuidString] = detailPlace
                    self.fetchPlaceImage(for: detailPlace.id.uuidString)
                    completion(detailPlace)
                }
            }
        }
    }
}
