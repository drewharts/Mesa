//  PlaceSelectionViewModel.swift
//  loc

import SwiftUI
import Combine
import CoreLocation

@MainActor
class PlaceSelectionViewModel: ObservableObject {
    private let photoImportVM: PhotoImportViewModel
    private let profileVM: ProfileViewModel
    private let selectedPlaceVM: SelectedPlaceViewModel
    private let detailPlaceVM: DetailPlaceViewModel

    @Published var showCreatePlacePopup = false
    @Published var selectedTypeFilter: String? = nil
    @Published private(set) var filteredPlaces: [NearbyPlaceFeature] = []
    @Published private(set) var availableTypeFilters: [String] = []

    private var cancellables = Set<AnyCancellable>()

    /// Initializes with all required dependencies for place selection and creation.
    init(
        photoImportVM: PhotoImportViewModel,
        profileVM: ProfileViewModel,
        selectedPlaceVM: SelectedPlaceViewModel,
        detailPlaceVM: DetailPlaceViewModel
    ) {
        self.photoImportVM = photoImportVM
        self.profileVM = profileVM
        self.selectedPlaceVM = selectedPlaceVM
        self.detailPlaceVM = detailPlaceVM
        setupSubscriptions()
    }

    // MARK: - Passthrough Properties

    /// The thumbnail image from the first selected photo.
    var photoThumbnail: UIImage? {
        photoImportVM.photoThumbnail
    }

    /// The GPS coordinates extracted from the selected photos.
    var detectedCoordinates: (latitude: Double, longitude: Double)? {
        photoImportVM.detectedCoordinates
    }

    /// Whether photos are currently being processed.
    var isProcessingPhoto: Bool {
        photoImportVM.isProcessingPhoto
    }

    /// Whether nearby places are currently loading.
    var isLoadingNearbyPlaces: Bool {
        photoImportVM.isLoadingNearbyPlaces
    }

    /// Whether a place is being saved or resolved.
    var isPlaceBusy: Bool {
        photoImportVM.isSavingPlace || photoImportVM.isResolvingPlace
    }

    /// The total count of nearby places found.
    var nearbyPlaceCount: Int {
        photoImportVM.nearbyPlaces.count
    }

    // MARK: - Subscriptions

    /// Subscribes to nearby places changes and recomputes filters and filtered list.
    private func setupSubscriptions() {
        photoImportVM.$nearbyPlaces
            .combineLatest($selectedTypeFilter)
            .sink { [weak self] places, typeFilter in
                self?.recomputeFilters(places: places, typeFilter: typeFilter)
            }
            .store(in: &cancellables)
    }

    /// Recomputes available type filters and the filtered places list.
    private func recomputeFilters(places: [NearbyPlaceFeature], typeFilter: String?) {
        // Build unique type list from all places
        var typeSet = Set<String>()
        for place in places {
            if let types = place.properties.types, let firstType = types.first {
                typeSet.insert(firstType)
            }
        }
        availableTypeFilters = typeSet.sorted()

        // Filter places by selected type
        if let typeFilter = typeFilter {
            filteredPlaces = places.filter { place in
                guard let types = place.properties.types else { return false }
                return types.contains(typeFilter)
            }
        } else {
            filteredPlaces = places
        }
    }

    // MARK: - Formatting

    /// Formats a distance in meters to a human-readable string (feet or miles).
    func formatDistance(meters: Double) -> String {
        let miles = meters * 0.000621371
        if miles < 0.1 {
            let feet = meters * 3.28084
            return String(format: "%.0f ft", feet)
        } else if miles < 1.0 {
            return String(format: "%.2f mi", miles)
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    /// Returns the emoji for a place based on its primary type.
    func placeTypeEmoji(for place: NearbyPlaceFeature) -> String {
        guard let types = place.properties.types, let firstType = types.first else {
            return "📍"
        }
        return PlaceTypeEmoji.emoji(for: firstType)
    }

    /// Returns a human-readable primary category for a place.
    func primaryCategory(for place: NearbyPlaceFeature) -> String {
        guard let types = place.properties.types, let firstType = types.first else {
            return "Place"
        }
        return firstType
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    // MARK: - Actions

    /// Sets the active type filter. Pass nil for "All".
    func filterByType(_ type: String?) {
        selectedTypeFilter = type
    }

    /// Creates a new user-defined place at the photo's coordinates.
    func createNewPlace(name: String, description: String?) {
        guard let coordinate = photoImportVM.detectedCoordinates,
              let userId = profileVM.user?.id else { return }

        let generatedId = UUID().uuidString
        let clCoordinate = CLLocationCoordinate2D(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )

        selectedPlaceVM.allowAutoPresent = true
        selectedPlaceVM.createNewPlace(
            idString: generatedId,
            name: name,
            description: description,
            coordinate: clCoordinate,
            userId: userId,
            profileVM: profileVM,
            detailPlaceVM: detailPlaceVM
        )

        let newNearbyPlace = buildNearbyPlaceFeature(
            id: generatedId,
            name: name,
            description: description,
            coordinate: coordinate
        )

        Task {
            await photoImportVM.selectPlace(newNearbyPlace)
        }
    }

    /// Selects a place from the nearby results and triggers resolution.
    func selectPlace(_ place: NearbyPlaceFeature) {
        selectedPlaceVM.allowAutoPresent = false
        Task {
            await photoImportVM.selectPlace(place)
        }
    }

    /// Dismisses the selection sheet. In multi-cluster mode, only clears cluster-scoped state.
    func cancel() {
        if photoImportVM.showClusterOverview {
            photoImportVM.clearClusterSelection()
        } else {
            photoImportVM.clearSelection()
        }
    }

    // MARK: - Helpers

    /// Builds a NearbyPlaceFeature for a newly created user place.
    private func buildNearbyPlaceFeature(
        id: String,
        name: String,
        description: String?,
        coordinate: (latitude: Double, longitude: Double)
    ) -> NearbyPlaceFeature {
        let properties = NearbyPlaceProperties(
            address: description ?? "User created location",
            distanceMeters: 0,
            name: name,
            source: "user_created",
            businessStatus: nil,
            createdAt: nil,
            openNow: nil,
            permanentlyClosed: nil,
            photoReference: nil,
            priceLevel: nil,
            rating: nil,
            types: nil,
            updatedAt: nil,
            userRatingsTotal: nil,
            description: description,
            id: id,
            placeId: nil
        )

        let geometry = NearbyPlaceGeometry(
            coordinates: [coordinate.longitude, coordinate.latitude],
            type: "Point"
        )

        return NearbyPlaceFeature(
            geometry: geometry,
            properties: properties,
            type: "Feature"
        )
    }
}
