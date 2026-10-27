//
//  PlaceDirections.swift
//  loc
//
//  Opens Apple Maps directions to a place (used by the group pick result).
//

import MapKit
import UIKit

enum PlaceDirections {
    /// Opens turn-by-turn directions to the place, or a name search if it has no coordinate.
    @MainActor
    static func open(_ place: DetailPlace) {
        if let coordinate = place.coordinate {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            item.name = place.name
            item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault])
            return
        }
        let query = [place.name, place.address].compactMap { $0 }.joined(separator: " ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
