//
//  Place.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//


import GoogleMaps
import GooglePlaces

struct Place {
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}

class PlaceService {
    func fetchPlaces(for query: String, completion: @escaping ([Place]) -> Void) {
        let placesClient = GMSPlacesClient.shared()
        let filter = GMSAutocompleteFilter()

        placesClient.findAutocompletePredictions(fromQuery: query, filter: filter, sessionToken: nil) { results, error in
            guard error == nil, let results = results else {
                completion([])
                return
            }

            let places = results.map { result in
                Place(name: result.attributedPrimaryText.string,
                      address: result.attributedSecondaryText?.string ?? "",
                      coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)) // Update with actual coordinates if needed
            }
            completion(places)
        }
    }
}
