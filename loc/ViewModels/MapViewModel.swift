//
//  MapViewModel.swift
//  loc
//
//  Coordinator ViewModel that composes child ViewModels for map functionality.
//

import Foundation
import MapKit
import SwiftUI

// MARK: - Sheet Type Enum
/// Identifies which sheet is currently being presented on the map.
enum MapSheetType: Identifiable, Equatable {
    case list(String)
    case tiktoks
    case reviews
    case favorites
    case myPlaces
    case externalReviews
    case externalList(String)
    case externalFavorites
    case keywordResults(keyword: String, types: [String])

    var id: String {
        switch self {
        case .list(let listId): return "list-\(listId)"
        case .tiktoks: return "tiktoks"
        case .reviews: return "reviews"
        case .favorites: return "favorites"
        case .myPlaces: return "myPlaces"
        case .externalReviews: return "externalReviews"
        case .externalList(let listId): return "externalList-\(listId)"
        case .externalFavorites: return "externalFavorites"
        case .keywordResults(let keyword, _): return "keywordResults-\(keyword)"
        }
    }
}

@MainActor
class MapViewModel: ObservableObject {
    // MARK: - Child ViewModels

    let filteringViewModel: MapFilteringViewModel
    let externalUserViewModel: MapExternalUserViewModel
    let photoViewModel: MapPhotoViewModel
    let viewportViewModel: MapViewportViewModel
    let selectionViewModel: MapAnnotationSelectionViewModel

    // MARK: - Sheet Coordination

    @Published var activeSheet: MapSheetType? = nil

    // MARK: - Proxy Properties for Backward Compatibility

    var viewportAnnotations: [PlaceAnnotation] { viewportViewModel.viewportAnnotations }
    var communityMarkers: [CommunityPlaceMarker] { viewportViewModel.communityMarkers }
    var isLoadingViewportPlaces: Bool { viewportViewModel.isLoadingViewportPlaces }
    var followedUsersPhotos: [FollowedUserPhoto] { photoViewModel.followedUsersPhotos }
    var annotationImages: [String: UIImage] { photoViewModel.annotationImages }
    var userProfilePictures: [String: UIImage] { photoViewModel.userProfilePictures }
    var hasLoadedPhotos: Bool { photoViewModel.hasLoadedPhotos }

    var selectedListId: String? { filteringViewModel.selectedListId }
    var showingTikToksOnMap: Bool { filteringViewModel.showingTikToksOnMap }
    var showingReviewsOnMap: Bool { filteringViewModel.showingReviewsOnMap }
    var showingFavoritesOnMap: Bool { filteringViewModel.showingFavoritesOnMap }
    var showingMyPlacesOnMap: Bool { filteringViewModel.showingMyPlacesOnMap }
    var keywordTypesFilter: [String]? { filteringViewModel.keywordTypesFilter }

    var externalUserId: String? { externalUserViewModel.externalUserId }
    var showingExternalReviewsOnMap: Bool { externalUserViewModel.showingExternalReviewsOnMap }
    var showingExternalFavoritesOnMap: Bool { externalUserViewModel.showingExternalFavoritesOnMap }
    var externalListId: String? { externalUserViewModel.externalListId }

    var preservedSelectedAnnotation: PlaceAnnotation? { selectionViewModel.preservedSelectedAnnotation }
    var pendingPlaceNavigation: String? {
        get { selectionViewModel.pendingPlaceNavigation }
        set { selectionViewModel.pendingPlaceNavigation = newValue }
    }

    // MARK: - Computed Sheet Properties

    var showingListPopup: Bool { if case .list = activeSheet { return true } else { return false } }
    var showingTikToksPopup: Bool { activeSheet == .tiktoks }
    var showingReviewsPopup: Bool { activeSheet == .reviews }
    var showingExternalReviewsPopup: Bool { activeSheet == .externalReviews }
    var showingExternalListPopup: Bool { if case .externalList = activeSheet { return true } else { return false } }
    var showingExternalFavoritesPopup: Bool { activeSheet == .externalFavorites }
    var showingFavoritesPopup: Bool { activeSheet == .favorites }
    var showingMyPlacesPopup: Bool { activeSheet == .myPlaces }
    var showingKeywordPopup: Bool { if case .keywordResults = activeSheet { return true } else { return false } }

    // MARK: - Initialization

    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.filteringViewModel = MapFilteringViewModel()
        self.externalUserViewModel = MapExternalUserViewModel()
        self.photoViewModel = MapPhotoViewModel(placeService: placeService)
        self.viewportViewModel = MapViewportViewModel(placeService: placeService)
        self.selectionViewModel = MapAnnotationSelectionViewModel()

        setupCallbacks()
    }

    /// Wires up callbacks between child ViewModels.
    private func setupCallbacks() {
        // When filtering changes, clear annotations and reset region for reload
        filteringViewModel.onFilterChanged = { [weak self] in
            self?.viewportViewModel.clearAnnotations()
            self?.viewportViewModel.resetLastLoadedRegion()
        }

        // When external user filtering changes, clear annotations and reset region for reload
        externalUserViewModel.onFilterChanged = { [weak self] in
            self?.viewportViewModel.clearAnnotations()
            self?.viewportViewModel.resetLastLoadedRegion()
        }

        // When external user is selected, load their profile photo
        externalUserViewModel.onExternalUserSelected = { [weak self] userId, photoUrl in
            guard let photoUrl = photoUrl else { return }
            Task { [weak self] in
                await self?.photoViewModel.loadExternalUserPhoto(userId: userId, photoUrl: photoUrl)
                self?.photoViewModel.generateAnnotationImages(for: self?.viewportViewModel.viewportAnnotations ?? [])
            }
        }

        // When annotations are loaded, regenerate annotation images
        viewportViewModel.onAnnotationsLoaded = { [weak self] annotations in
            self?.photoViewModel.generateAnnotationImages(for: annotations)
        }
    }

    // MARK: - List Filtering (Coordinator Methods)

    /// Validates that a list exists and sets it as the selected list for filtering.
    func selectList(_ listId: String, availableLists: [LightweightPlaceList]) {
        guard filteringViewModel.selectList(listId, availableLists: availableLists) else { return }
        activeSheet = .list(listId)
    }

    /// Clears the list filter and restores all annotations.
    func clearListFilter() {
        filteringViewModel.clearListFilter()
        activeSheet = nil
    }

    /// Sets the map to show only TikTok places.
    func selectTikToks() {
        filteringViewModel.selectTikToks()
        activeSheet = .tiktoks
    }

    /// Sets the map to show only reviewed places.
    func selectReviews() {
        filteringViewModel.selectReviews()
        activeSheet = .reviews
    }

    /// Sets the map to show only favorite places.
    func selectFavorites() {
        filteringViewModel.selectFavorites()
        activeSheet = .favorites
    }

    /// Sets the map to show only user's created places.
    func selectMyPlaces() {
        filteringViewModel.selectMyPlaces()
        activeSheet = .myPlaces
    }

    /// Shows keyword search results on the map.
    func selectKeywordResults(keyword: String, types: [String]) {
        filteringViewModel.selectKeywordResults(keyword: keyword, types: types)
        activeSheet = .keywordResults(keyword: keyword, types: types)
    }

    // MARK: - External User Filtering (Coordinator Methods)

    /// Shows external user's reviews on the map.
    func selectExternalReviews(userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalReviews(userId: userId, userPhotoUrl: userPhotoUrl)
        activeSheet = .externalReviews
    }

    /// Shows external user's list on the map.
    func selectExternalList(listId: String, userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalList(listId: listId, userId: userId, userPhotoUrl: userPhotoUrl)
        activeSheet = .externalList(listId)
    }

    /// Shows external user's favorites on the map.
    func selectExternalFavorites(userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalFavorites(userId: userId, userPhotoUrl: userPhotoUrl)
        activeSheet = .externalFavorites
    }

    // MARK: - Clear Filters

    /// Clears all special filters (list, TikToks, reviews, favorites, my places, external).
    func clearAllFilters() {
        filteringViewModel.clearAllFilters()
        externalUserViewModel.clearAllFilters()
        viewportViewModel.clearAnnotations()
        viewportViewModel.resetLastLoadedRegion()
        // Note: activeSheet is NOT cleared here - it's managed by the sheet presentation logic
    }

    /// Clears only user filters (not external user filters).
    private func clearUserFilters() {
        filteringViewModel.clearAllFilters()
    }

    // MARK: - Annotation Selection (Delegated)

    /// Sets a preserved annotation from a DetailPlace so it remains visible during zoom out.
    func setPreservedAnnotation(for place: DetailPlace?) {
        selectionViewModel.setPreservedAnnotation(for: place)
    }

    /// Clears the preserved annotation.
    func clearPreservedAnnotation() {
        selectionViewModel.clearPreservedAnnotation()
    }

    // MARK: - Photo Loading (Delegated)

    /// Loads profile photos for followed users.
    func loadFollowedUsersPhotos(userId: String, currentUserPhotoUrl: URL?) async {
        await photoViewModel.loadFollowedUsersPhotos(userId: userId, currentUserPhotoUrl: currentUserPhotoUrl)
        photoViewModel.generateAnnotationImages(for: viewportViewModel.viewportAnnotations)
    }

    /// Generates combined annotation images for all annotations.
    func generateAnnotationImages() {
        photoViewModel.generateAnnotationImages(for: viewportViewModel.viewportAnnotations)
    }

    // MARK: - Place Details (Delegated)

    /// Loads full place details on demand when user taps an annotation.
    func loadPlaceDetails(for annotation: PlaceAnnotation) async -> DetailPlace? {
        return await viewportViewModel.loadPlaceDetails(for: annotation)
    }

    /// Loads full place details for a community marker.
    func loadPlaceDetails(for marker: CommunityPlaceMarker) async -> DetailPlace? {
        return await viewportViewModel.loadPlaceDetails(for: marker)
    }

    // MARK: - Viewport Loading (Delegated)

    /// Called when the map camera has settled.
    func onMapCameraSettled(_ newRegion: MKCoordinateRegion, userId: String) async {
        let filterState = buildFilterState()
        await viewportViewModel.onMapCameraSettled(newRegion, userId: userId, filterState: filterState)
    }

    /// Filters annotations for current viewport.
    func getAnnotationsForViewport(_ region: MKCoordinateRegion) -> [PlaceAnnotation] {
        return viewportViewModel.getAnnotationsForViewport(region)
    }

    /// Returns all place annotations to display on map.
    func getAllDisplayAnnotations() -> [PlaceAnnotation] {
        return viewportViewModel.getAllDisplayAnnotations()
    }

    // MARK: - Private Helpers

    /// Builds the current filter state from child ViewModels.
    private func buildFilterState() -> MapFilterState {
        return MapFilterState(
            selectedListId: filteringViewModel.selectedListId,
            showingTikToksOnMap: filteringViewModel.showingTikToksOnMap,
            showingReviewsOnMap: filteringViewModel.showingReviewsOnMap,
            showingFavoritesOnMap: filteringViewModel.showingFavoritesOnMap,
            showingMyPlacesOnMap: filteringViewModel.showingMyPlacesOnMap,
            showingKeywordResultsPopup: filteringViewModel.showingKeywordResultsPopup,
            keywordTypesFilter: filteringViewModel.keywordTypesFilter,
            externalUserId: externalUserViewModel.externalUserId,
            showingExternalReviewsOnMap: externalUserViewModel.showingExternalReviewsOnMap,
            showingExternalFavoritesOnMap: externalUserViewModel.showingExternalFavoritesOnMap,
            externalListId: externalUserViewModel.externalListId
        )
    }
}
