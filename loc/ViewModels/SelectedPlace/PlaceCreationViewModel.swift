//
//  PlaceCreationViewModel.swift
//  loc
//
//  Manages custom place creation logic.
//  Single Responsibility: Only handles creating and saving custom places.
//

import Foundation
import CoreLocation

@MainActor
class PlaceCreationViewModel: ObservableObject {
    // MARK: - Dependencies

    private let placeService: PlaceService

    // MARK: - Callbacks

    /// Called when a new place is created and ready for selection.
    var onPlaceCreated: ((DetailPlace) -> Void)?

    // MARK: - Initialization

    /// Initializes with required services.
    init(placeService: PlaceService) {
        self.placeService = placeService
    }

    // MARK: - Public Methods

    /// Creates a new custom place.
    func createNewPlace(
        idString: String?,
        name: String,
        description: String?,
        coordinate: CLLocationCoordinate2D,
        userId: String,
        profileVM: ProfileViewModel? = nil,
        detailPlaceVM: DetailPlaceViewModel? = nil
    ) {
        // Create a new place
        var newPlace = DetailPlace()
        if let idString = idString, let uuid = UUID(uuidString: idString) {
            newPlace.id = uuid
        }
        newPlace.name = name
        newPlace.description = description
        newPlace.coordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        newPlace.isCustom = true

        // Immediately update local state for instant UI feedback
        updateLocalState(newPlace: newPlace, userId: userId, profileVM: profileVM, detailPlaceVM: detailPlaceVM)

        // Save to database
        saveToDatabase(newPlace: newPlace, userId: userId)

        // Notify that place is created
        onPlaceCreated?(newPlace)
    }

    // MARK: - Private Methods

    /// Updates local state for instant UI feedback.
    private func updateLocalState(
        newPlace: DetailPlace,
        userId: String,
        profileVM: ProfileViewModel?,
        detailPlaceVM: DetailPlaceViewModel?
    ) {
        // Add to DetailPlaceViewModel's places dictionary
        if let detailPlaceVM = detailPlaceVM {
            detailPlaceVM.places[newPlace.id.uuidString] = newPlace

            // Add current user to placeSavers for this place
            detailPlaceVM.placeSavers[newPlace.id.uuidString] = [userId]

            // Trigger annotation calculation for immediate display
            detailPlaceVM.calculateAnnotationPlaces()

            // Generate color for the new place
            detailPlaceVM.generateColorForPlace(newPlace.id.uuidString)
        }

        // Update ProfileViewModel's myPlaces list
        if let profileVM = profileVM {
            if !profileVM.myPlacesViewModel.myPlaces.contains(newPlace.id.uuidString) {
                profileVM.myPlacesViewModel.myPlaces.append(newPlace.id.uuidString)
            }
        }

        // Send notification to refresh map annotations
        NotificationCenter.default.post(name: NSNotification.Name("RefreshMapAnnotations"), object: nil)
    }

    /// Saves the new place to database.
    private func saveToDatabase(newPlace: DetailPlace, userId: String) {
        Task {
            SupabasePlaceService.shared.testSupabaseConnection { [weak self] isConnected, error in
                guard let self = self else { return }

                if !isConnected {
                    print("❌ [PlaceCreationVM] Supabase connection failed: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                // Save to main places collection
                self.placeService.addToAllPlaces(place: newPlace) { error in
                    if let error = error {
                        print("❌ [PlaceCreationVM] Error saving place to main collection: \(error.localizedDescription)")
                    } else {
                        // Save to user's myPlaces collection
                        self.placeService.addToMyPlaces(userId: userId, place: newPlace) { error in
                            if let error = error {
                                print("❌ [PlaceCreationVM] Error saving place to user's collection: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        }
    }
}
