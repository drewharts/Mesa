//
//  MapKitService.swift
//  loc
//
//  Created by Andrew Hartsfield II on 2/2/25.
//

import Foundation
import MapKit

class MapKitService {
    // A shared instance (optional) for convenience.
    static let shared = MapKitService()
    
    /// Calculates driving travel time (in seconds) between an origin and destination.
    func calculateTravelTime(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        completion: @escaping (TimeInterval?, Error?) -> Void
    ) {
        let sourcePlacemark = MKPlacemark(coordinate: origin)
        let destinationPlacemark = MKPlacemark(coordinate: destination)
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: sourcePlacemark)
        request.destination = MKMapItem(placemark: destinationPlacemark)
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { response, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            if let route = response?.routes.first {
                // expectedTravelTime is returned in seconds.
                completion(route.expectedTravelTime, nil)
            } else {
                completion(nil, nil)
            }
        }
    }
}
