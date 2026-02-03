//
//  ListsDistanceSortingViewModel.swift
//  loc
//
//  Child ViewModel for distance-based list sorting.
//

import SwiftUI
import CoreLocation

/// Manages distance-based list sorting operations.
@MainActor
class ListsDistanceSortingViewModel: ObservableObject {
    // MARK: - Private State

    private var hasPerformedInitialSort = false

    // MARK: - Dependencies

    private weak var userSession: UserSession?
    private weak var locationManager: LocationManager?

    // MARK: - ViewModel References

    private weak var dataViewModel: ListsDataViewModel?

    // MARK: - Callbacks

    /// Called to get place coordinate for distance calculation.
    var getPlaceCoordinate: ((String) -> CLLocationCoordinate2D?)?

    // MARK: - Initialization

    /// Initializes the distance sorting view model with required dependencies.
    init(userSession: UserSession, locationManager: LocationManager, dataViewModel: ListsDataViewModel) {
        self.userSession = userSession
        self.locationManager = locationManager
        self.dataViewModel = dataViewModel
    }

    // MARK: - Computed Properties

    /// Whether the initial sort has been performed.
    var hasCompletedInitialSort: Bool {
        hasPerformedInitialSort
    }

    // MARK: - List Sorting by Distance

    /// Sorts userLists by their distance from the user's current location (closest first).
    func sortListsByDistance() {
        guard let dataVM = dataViewModel else { return }
        guard locationManager?.currentLocation != nil else { return }

        dataVM.userLists.sort { list1, list2 in
            let distance1 = calculateDistanceToList(list1)
            let distance2 = calculateDistanceToList(list2)

            if distance1 != Double.infinity && distance2 != Double.infinity {
                return distance1 < distance2
            } else if distance1 != Double.infinity {
                return true
            } else if distance2 != Double.infinity {
                return false
            } else {
                return list1.name < list2.name
            }
        }

        hasPerformedInitialSort = true
    }

    /// Calculates the distance from the user's current location to a list.
    func calculateDistanceToList(_ list: PlaceList) -> Double {
        guard let currentLocation = locationManager?.currentLocation,
              let dataVM = dataViewModel else {
            return Double.infinity
        }

        // Use pre-calculated average coordinates if available
        if let averageCoordinate = list.averageCoordinate {
            let listLocation = CLLocation(
                latitude: averageCoordinate.latitude,
                longitude: averageCoordinate.longitude
            )
            return currentLocation.distance(from: listLocation)
        }

        // Fallback to calculating average distance from individual places
        let listPlaceIds = dataVM.userListsPlaces[list.id.uuidString] ?? []
        guard !listPlaceIds.isEmpty else { return Double.infinity }

        var totalDistance: Double = 0
        var validPlaceCount: Int = 0

        for placeId in listPlaceIds {
            if let coordinate = getPlaceCoordinate?(placeId) {
                let placeLocation = CLLocation(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )
                totalDistance += currentLocation.distance(from: placeLocation)
                validPlaceCount += 1
            }
        }

        return validPlaceCount > 0 ? totalDistance / Double(validPlaceCount) : Double.infinity
    }

    /// Recalculates the average coordinates for a specific list.
    func recalculateAverageCoordinates(for listId: UUID) {
        guard let dataVM = dataViewModel,
              let listIndex = dataVM.userLists.firstIndex(where: { $0.id == listId }),
              let placeIds = dataVM.userListsPlaces[listId.uuidString] else {
            return
        }

        var totalLatitude: Double = 0
        var totalLongitude: Double = 0
        var validPlaceCount: Int = 0

        for placeId in placeIds {
            if let coordinate = getPlaceCoordinate?(placeId) {
                totalLatitude += coordinate.latitude
                totalLongitude += coordinate.longitude
                validPlaceCount += 1
            }
        }

        if validPlaceCount > 0 {
            let averageLatitude = totalLatitude / Double(validPlaceCount)
            let averageLongitude = totalLongitude / Double(validPlaceCount)

            dataVM.userLists[listIndex].averageCoordinate = CLLocationCoordinate2D(
                latitude: averageLatitude,
                longitude: averageLongitude
            )
            dataVM.userLists[listIndex].lastCoordinateUpdate = Date()

            // Persist to backend
            if let userId = userSession?.currentUserId {
                Task {
                    await updateListAverageCoordinates(
                        userId: userId,
                        listId: listId,
                        averageCoordinate: dataVM.userLists[listIndex].averageCoordinate!
                    )
                }
            }
        } else {
            dataVM.userLists[listIndex].averageCoordinate = nil
            dataVM.userLists[listIndex].lastCoordinateUpdate = Date()
        }
    }

    /// Updates the average coordinates in Supabase.
    private func updateListAverageCoordinates(userId: String, listId: UUID, averageCoordinate: CLLocationCoordinate2D) async {
        // TODO: Implement with Supabase
        print("⚠️ updateListAverageCoordinates not yet implemented for Supabase")
    }

    // MARK: - Reset

    /// Resets the initial sort flag.
    func resetSortingState() {
        hasPerformedInitialSort = false
    }
}
