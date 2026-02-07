//
//  MapAnnotationSelectionViewModel.swift
//  loc
//
//  Manages preserving selected annotations during zoom operations.
//

import Foundation
import MapKit

@MainActor
class MapAnnotationSelectionViewModel: ObservableObject {
    @Published var preservedSelectedAnnotation: PlaceAnnotation?
    @Published var pendingPlaceNavigation: String?

    // MARK: - Annotation Preservation

    /// Sets a preserved annotation from a DetailPlace so it remains visible during zoom out.
    /// Clears the annotation if the place has no valid coordinates (nil or 0,0).
    /// Valid coordinates may arrive later via a fresh details fetch, at which point
    /// the shouldAnimateMapToPlace observer will re-call this method.
    func setPreservedAnnotation(for place: DetailPlace?) {
        guard let place = place,
              let coord = place.coordinate,
              coord.isValidForNavigation else {
            preservedSelectedAnnotation = nil
            return
        }
        preservedSelectedAnnotation = PlaceAnnotation(
            id: place.id.uuidString,
            name: place.name,
            coordinate: CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude),
            userIds: [],
            placeType: place.categories?.first ?? "other"
        )
    }

    /// Clears the preserved annotation when deselecting a place.
    func clearPreservedAnnotation() {
        preservedSelectedAnnotation = nil
    }
}
