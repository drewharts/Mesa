//  CreatePlaceSheetViewModel.swift
//  loc

import Foundation
import CoreLocation

@MainActor
class CreatePlaceSheetViewModel: ObservableObject {
    @Published var placeName: String = ""
    @Published var placeDescription: String = ""
    @Published var isLoading: Bool = false

    let coordinate: CLLocationCoordinate2D

    /// Returns true when the place name is non-empty after trimming whitespace.
    var canCreate: Bool {
        !placeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Returns the trimmed description, or nil if it is empty.
    var trimmedDescription: String? {
        let trimmed = placeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Initializes the view model with the coordinate for the new place.
    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
    }
}
