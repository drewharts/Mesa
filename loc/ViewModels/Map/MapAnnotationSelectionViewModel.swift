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
    func setPreservedAnnotation(for place: DetailPlace?) {
        guard let place = place, let coord = place.coordinate else {
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
