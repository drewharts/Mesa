//
//  PlacesClientProtocol.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/20/25.
//

import GooglePlaces
import UIKit

protocol PlacesClientProtocol {
    func fetchPlace(fromPlaceID placeID: String, placeFields: GMSPlaceField, sessionToken: GMSAutocompleteSessionToken?, callback: @escaping GMSPlaceResultCallback)
    func lookUpPhotos(forPlaceID placeID: String, callback: @escaping GMSPlacePhotoMetadataResultCallback)
    func loadPlacePhoto(_ photoMetadata: GMSPlacePhotoMetadata, callback: @escaping GMSPlacePhotoImageResultCallback)
}

extension GMSPlacesClient: PlacesClientProtocol {}

