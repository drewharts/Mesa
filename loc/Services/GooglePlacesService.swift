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
