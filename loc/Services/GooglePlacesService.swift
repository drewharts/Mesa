//
//  GooglePlacesService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/5/25.
//


import GooglePlaces
import UIKit

class GooglePlacesService {
    private let placesClient = GMSPlacesClient.shared()
    
    func performSearch(query: String, userLocation: CLLocationCoordinate2D?, completion: @escaping ([GMSAutocompletePrediction]?, Error?) -> Void) {
        let filter = GMSAutocompleteFilter()
        filter.types = ["restaurant"]

        if let location = userLocation {
            filter.locationBias = GMSPlaceRectangularLocationOption(
                CLLocationCoordinate2D(latitude: location.latitude + 0.01, longitude: location.longitude + 0.01),
                CLLocationCoordinate2D(latitude: location.latitude - 0.01, longitude: location.longitude - 0.01)
            )
        }

        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { results, error in
            completion(results, error)
        }
    }
    
    func isRestaurantOpenNow(placeID: String, completion: @escaping (Bool, Error?) -> Void) {
        // First, fetch the GMSPlace object
        fetchPlace(placeID: placeID) { [weak self] place, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let place = place else {
                // No place was returned, so we can’t check if it’s open
                completion(false, nil)
                return
            }
            
            // Use the GMSPlacesClient isOpen API
            self?.placesClient.isOpen(with: place) { openStatus, error in
                if let error = error {
                    completion(false, error)
                    return
                }
                
                // Translate GMSPlacesOpenStatus (.open, .closed, .unknown) to a Bool
                switch openStatus {
                case .open:
                    completion(true, nil)
                case .closed, .unknown:
                    completion(false, nil)
                @unknown default:
                    completion(false, nil)
                }
            }
        }
    }
    
    func fetchPlace(placeID: String, completion: @escaping (GMSPlace?, Error?) -> Void) {
        let requestedProperties = [GMSPlaceProperty.all].map { $0.rawValue }
        let placeRequest = GMSFetchPlaceRequest(
            placeID: placeID,
            placeProperties: requestedProperties,
            sessionToken: nil
        )

        placesClient.fetchPlace(with: placeRequest) { (place, error) in
            if let error = error {
                print("Error fetching place: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            completion(place, nil)
        }
    }
    
    func fetchPhoto(placeID: String, completion: @escaping (UIImage?) -> Void) {
        placesClient.lookUpPhotos(forPlaceID: placeID) { [weak self] (photosMetadata, error) in
            guard let firstMeta = photosMetadata?.results.first, error == nil else {
                completion(nil)
                return
            }

            self?.placesClient.loadPlacePhoto(firstMeta) { (photo, error) in
                guard let photo = photo, error == nil else {
                    completion(nil)
                    return
                }
                completion(photo)
            }
        }
    }
}
