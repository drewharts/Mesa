//
//  KeywordResultsPopupView.swift
//  loc
//
//  Single Responsibility: Display paginated keyword search results in a popup grid
//  Shows places matching keyword types (e.g., "french" -> French restaurants)
//  Uses PlaceListPopupView wrapper for consistent popup behavior with other views
//

import SwiftUI
import MapKit

struct KeywordResultsPopupView: View {
    let keyword: String
    let types: [String]

    @EnvironmentObject var mapViewModel: MapViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var appCoordinator: AppCoordinator

    // MARK: - State

    @State private var places: [LightweightPlace] = []
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var hasMore = false
    @State private var offset = 0
    @State private var lastLoadedRegion: MKCoordinateRegion?

    private let pageSize = 20

    // MARK: - Body

    var body: some View {
        PlaceListPopupView(
            title: "\(keyword.capitalized) nearby",
            count: places.isEmpty ? nil : places.count + (hasMore ? 1 : 0),
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            places: places,
            hasMore: hasMore,
            emptyIcon: "mappin.slash",
            emptyTitle: "No Places Found",
            emptyMessage: "No \(keyword) places found in this area",
            loadMore: { await loadMore() },
            cardBuilder: { place, navigate in
                PopupPlaceCard(
                    place: place,
                    preferExternalThumbnail: false,
                    onNavigate: navigate
                )
            }
        )
        .task {
            await loadInitialData()
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.latitude) { _, _ in
            Task {
                await reloadIfRegionChanged()
            }
        }
        .onChange(of: appCoordinator.currentMapRegion?.center.longitude) { _, _ in
            Task {
                await reloadIfRegionChanged()
            }
        }
    }

    // MARK: - Data Loading

    private func loadInitialData() async {
        isLoading = true
        offset = 0

        guard let bounds = getViewportBounds() else {
            isLoading = false
            return
        }

        // Track the region we're loading for
        lastLoadedRegion = appCoordinator.currentMapRegion

        do {
            let results = try await SupabasePlaceService.shared.searchPlacesByTypesWithPhotos(
                types: types,
                bounds: bounds,
                limit: pageSize + 1,
                offset: 0
            )

            if results.count > pageSize {
                places = Array(results.prefix(pageSize))
                hasMore = true
            } else {
                places = results
                hasMore = false
            }
            offset = places.count
        } catch {
            if !Task.isCancelled {
                print("❌ [KeywordResultsPopupView] Error loading places: \(error)")
            }
        }

        isLoading = false
    }

    /// Reload places when user pans/zooms the map significantly
    private func reloadIfRegionChanged() async {
        guard let currentRegion = appCoordinator.currentMapRegion else { return }

        // Check if region changed significantly (threshold: ~20% of span)
        if let lastRegion = lastLoadedRegion {
            let latDiff = abs(currentRegion.center.latitude - lastRegion.center.latitude)
            let lngDiff = abs(currentRegion.center.longitude - lastRegion.center.longitude)
            let threshold = max(lastRegion.span.latitudeDelta, lastRegion.span.longitudeDelta) * 0.2

            // Skip if movement is too small
            if latDiff < threshold && lngDiff < threshold {
                return
            }
        }

        // Reload with new region
        await loadInitialData()
    }

    private func loadMore() async {
        guard !isLoadingMore, hasMore else { return }
        isLoadingMore = true

        guard let bounds = getViewportBounds() else {
            isLoadingMore = false
            return
        }

        do {
            let results = try await SupabasePlaceService.shared.searchPlacesByTypesWithPhotos(
                types: types,
                bounds: bounds,
                limit: pageSize + 1,
                offset: offset
            )

            if results.count > pageSize {
                places.append(contentsOf: Array(results.prefix(pageSize)))
                hasMore = true
            } else {
                places.append(contentsOf: results)
                hasMore = false
            }
            offset = places.count
        } catch {
            if !Task.isCancelled {
                print("❌ [KeywordResultsPopupView] Error loading more places: \(error)")
            }
        }

        isLoadingMore = false
    }

    // MARK: - Helpers

    /// Get adaptive viewport bounds using map region or user location as fallback
    /// Bounds are normalized to min/max thresholds for consistent search results
    private func getViewportBounds() -> (northLat: Double, southLat: Double, eastLng: Double, westLng: Double)? {
        return ViewportBoundsHelper.getAdaptiveBounds(
            from: appCoordinator.currentMapRegion,
            fallbackLocation: locationManager.currentLocation?.coordinate
        )
    }
}
