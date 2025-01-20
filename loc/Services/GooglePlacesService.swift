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
    
    /// Fetches a GMSPlace object based on the provided placeID.
    ///
    /// - Parameters:
    ///   - placeID: The unique identifier of the place to fetch.
    ///   - completion: A closure that returns a GMSPlace object or an Error.
    func fetchPlace(placeID: String, completion: @escaping (GMSPlace?, Error?) -> Void) {
        // Request *all* fields (everything the SDK can return)
        let fields: GMSPlaceField = .all
        
        placesClient.fetchPlace(fromPlaceID: placeID, placeFields: fields, sessionToken: nil) { place, error in
            if let error = error {
                print("Error fetching place: \(error.localizedDescription)")
                completion(nil, error)
                return
            }
            
            guard let place = place else {
                print("No place details found.")
                completion(nil, nil)
                return
            }
            
            // Successfully retrieved the place, with all fields that are available
            completion(place, nil)
        }
    }

    
    /// Example function to fetch a photo for a given placeID.
    func fetchPhoto(placeID: String, completion: @escaping (UIImage?) -> Void) {
        // 1) Fetch Photo Metadata
        placesClient.lookUpPhotos(forPlaceID: placeID) { [weak self] (photosMetadata, error) in
            guard
                error == nil,
                let firstMeta = photosMetadata?.results.first
            else {
                completion(nil)
                return
            }
            
            // 2) Use the metadata to load the actual UIImage
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

