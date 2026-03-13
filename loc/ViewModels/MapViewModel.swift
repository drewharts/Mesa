//
//  MapViewModel.swift
//  loc
//
//  Coordinator ViewModel that composes child ViewModels for map functionality.
//

import Combine
import Foundation
import MapKit
import SwiftUI

@MainActor
class MapViewModel: ObservableObject {
    // MARK: - Child ViewModels

    let filteringViewModel: MapFilteringViewModel
    let externalUserViewModel: MapExternalUserViewModel
    let photoViewModel: MapPhotoViewModel
    let viewportViewModel: MapViewportViewModel
    let selectionViewModel: MapAnnotationSelectionViewModel
    let tapDiscoveryViewModel: MapTapDiscoveryViewModel
    let cityAnnotationViewModel: MapCityAnnotationViewModel

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Proxy Properties for Backward Compatibility

    var viewportAnnotations: [PlaceAnnotation] { viewportViewModel.viewportAnnotations }
    var communityMarkers: [CommunityPlaceMarker] { viewportViewModel.communityMarkers }
    var isLoadingViewportPlaces: Bool { viewportViewModel.isLoadingViewportPlaces }
    var followedUsersPhotos: [FollowedUserPhoto] { photoViewModel.followedUsersPhotos }
    var annotationImages: [String: UIImage] { photoViewModel.annotationImages }
    var userProfilePictures: [String: UIImage] { photoViewModel.userProfilePictures }
    var hasLoadedPhotos: Bool { photoViewModel.hasLoadedPhotos }

    var selectedListId: String? { filteringViewModel.selectedListId }
    var showingExternalPlacesOnMap: Bool { filteringViewModel.showingExternalPlacesOnMap }
    var showingReviewsOnMap: Bool { filteringViewModel.showingReviewsOnMap }
    var showingFavoritesOnMap: Bool { filteringViewModel.showingFavoritesOnMap }
    var showingMyPlacesOnMap: Bool { filteringViewModel.showingMyPlacesOnMap }
    var keywordTypesFilter: [String]? { filteringViewModel.keywordTypesFilter }

    var externalUserId: String? { externalUserViewModel.externalUserId }
    var showingExternalReviewsOnMap: Bool { externalUserViewModel.showingExternalReviewsOnMap }
    var showingExternalFavoritesOnMap: Bool { externalUserViewModel.showingExternalFavoritesOnMap }
    var externalListId: String? { externalUserViewModel.externalListId }

    var preservedSelectedAnnotation: PlaceAnnotation? { selectionViewModel.preservedSelectedAnnotation }

    var cityAnnotations: [CityAnnotation] { cityAnnotationViewModel.cityAnnotations }

    /// Whether the map is currently showing city-level annotations instead of place annotations.
    @Published var showingCityAnnotations: Bool = false

    /// Pending place navigation - bridged to PresentationService for sheet views to observe.
    var pendingPlaceNavigation: String? {
        get { PresentationService.shared.pendingPlaceNavigation }
        set { PresentationService.shared.pendingPlaceNavigation = newValue }
    }

    /// Controls how map annotations are displayed (everyone, categories, or my places).
    @Published var annotationDisplayMode: AnnotationDisplayMode = .everyone

    /// Whether to show hybrid (satellite + labels) map style instead of standard.
    @Published var isSatelliteMap: Bool = false

    /// The current user's ID, used for "My Places" filtering.
    var currentUserId: String?

    /// Whether annotations show category emojis instead of profile photos.
    var showEmojiAnnotations: Bool { annotationDisplayMode == .categories }

    /// Whether only the current user's annotations should be shown.
    var showMyPlacesOnly: Bool { annotationDisplayMode == .myPlaces }

    // MARK: - Computed Sheet Properties (Read from PresentationService)

    var showingListPopup: Bool {
        guard let sheet = PresentationService.shared.activeSheet else { return false }
        if case .list = sheet { return true }
        return false
    }
    var showingExternalPlacesPopup: Bool { PresentationService.shared.activeSheet == .externalVideos }
    var showingReviewsPopup: Bool { PresentationService.shared.activeSheet == .reviews }
    var showingExternalReviewsPopup: Bool { PresentationService.shared.activeSheet == .externalReviews }
    var showingExternalListPopup: Bool {
        guard let sheet = PresentationService.shared.activeSheet else { return false }
        if case .externalList = sheet { return true }
        return false
    }
    var showingExternalFavoritesPopup: Bool { PresentationService.shared.activeSheet == .externalFavorites }
    var showingFavoritesPopup: Bool { PresentationService.shared.activeSheet == .favorites }
    var showingMyPlacesPopup: Bool { PresentationService.shared.activeSheet == .myPlaces }
    var showingKeywordPopup: Bool {
        guard let sheet = PresentationService.shared.activeSheet else { return false }
        if case .keywordResults = sheet { return true }
        return false
    }

    // MARK: - Initialization

    init(placeService: PlaceService, detailPlaceVM: DetailPlaceViewModel) {
        self.filteringViewModel = MapFilteringViewModel()
        self.externalUserViewModel = MapExternalUserViewModel()
        self.photoViewModel = MapPhotoViewModel(placeService: placeService)
        self.viewportViewModel = MapViewportViewModel(placeService: placeService)
        self.selectionViewModel = MapAnnotationSelectionViewModel()
        self.tapDiscoveryViewModel = MapTapDiscoveryViewModel()
        self.cityAnnotationViewModel = MapCityAnnotationViewModel(placeService: placeService)

        setupCallbacks()
    }

    /// Wires up callbacks between child ViewModels.
    private func setupCallbacks() {
        setupTapDiscoveryForwarding()
        setupFilterCallbacks()
        setupExternalUserCallbacks()
        setupAnnotationCallbacks()
        setupCityAnnotationForwarding()
    }

    /// Forwards tap discovery state changes so MapView overlay updates.
    private func setupTapDiscoveryForwarding() {
        tapDiscoveryViewModel.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// Clears annotations when filtering changes so the viewport reloads.
    private func setupFilterCallbacks() {
        filteringViewModel.onFilterChanged = { [weak self] in
            self?.viewportViewModel.clearAnnotations()
            self?.viewportViewModel.resetLastLoadedRegion()
        }

        externalUserViewModel.onFilterChanged = { [weak self] in
            self?.viewportViewModel.clearAnnotations()
            self?.viewportViewModel.resetLastLoadedRegion()
        }
    }

    /// Loads external user profile photo when selected.
    private func setupExternalUserCallbacks() {
        externalUserViewModel.onExternalUserSelected = { [weak self] userId, photoUrl in
            guard let photoUrl = photoUrl else { return }
            Task { [weak self] in
                await self?.photoViewModel.loadExternalUserPhoto(userId: userId, photoUrl: photoUrl)
                self?.photoViewModel.generateAnnotationImages(for: self?.viewportViewModel.viewportAnnotations ?? [])
            }
        }
    }

    /// Regenerates annotation images when annotations are loaded.
    private func setupAnnotationCallbacks() {
        viewportViewModel.onAnnotationsLoaded = { [weak self] annotations in
            self?.photoViewModel.generateAnnotationImages(for: annotations)
        }
    }

    /// Forwards city annotation state changes so MapView re-renders.
    private func setupCityAnnotationForwarding() {
        cityAnnotationViewModel.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - List Filtering (Coordinator Methods)

    /// Validates that a list exists and sets it as the selected list for filtering.
    func selectList(_ listId: String, availableLists: [LightweightPlaceList]) {
        guard filteringViewModel.selectList(listId, availableLists: availableLists) else { return }
        PresentationService.shared.present(.list(listId: listId))
    }

    /// Applies list filter to the map without presenting a sheet.
    func applyListFilter(_ listId: String, availableLists: [LightweightPlaceList]) {
        _ = filteringViewModel.selectList(listId, availableLists: availableLists)
    }

    /// Clears the list filter and restores all annotations.
    /// Note: Does NOT dismiss the sheet - that's handled by the sheet's own dismissal flow.
    func clearListFilter() {
        filteringViewModel.clearListFilter()
        // Don't call PresentationService.shared.dismiss() here - it creates a cycle
        // when handleMapPopupDisappear() sets selectedListIdForMap = nil
    }

    /// Sets the map to show only external places.
    func selectExternalPlaces() {
        filteringViewModel.selectExternalPlaces()
        PresentationService.shared.present(.externalVideos)
    }

    /// Sets the map to show only reviewed places.
    func selectReviews() {
        filteringViewModel.selectReviews()
        PresentationService.shared.present(.reviews)
    }

    /// Sets the map to show only favorite places.
    func selectFavorites() {
        filteringViewModel.selectFavorites()
        PresentationService.shared.present(.favorites)
    }

    /// Sets the map to show only user's created places.
    func selectMyPlaces() {
        filteringViewModel.selectMyPlaces()
        PresentationService.shared.present(.myPlaces)
    }

    /// Shows keyword search results on the map.
    func selectKeywordResults(keyword: String, types: [String]) {
        filteringViewModel.selectKeywordResults(keyword: keyword, types: types)
        PresentationService.shared.present(.keywordResults(keyword: keyword, types: types))
    }

    // MARK: - External User Filtering (Coordinator Methods)

    /// Shows external user's reviews on the map.
    func selectExternalReviews(userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalReviews(userId: userId, userPhotoUrl: userPhotoUrl)
        PresentationService.shared.present(.externalReviews)
    }

    /// Shows external user's list on the map.
    func selectExternalList(listId: String, userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalList(listId: listId, userId: userId, userPhotoUrl: userPhotoUrl)
        PresentationService.shared.present(.externalList(listId: listId))
    }

    /// Shows external user's favorites on the map.
    func selectExternalFavorites(userId: String, userPhotoUrl: URL?) {
        clearUserFilters()
        externalUserViewModel.selectExternalFavorites(userId: userId, userPhotoUrl: userPhotoUrl)
        PresentationService.shared.present(.externalFavorites)
    }

    // MARK: - Clear Filters

    /// Returns true if the given sheet type requires clearing map filters when dismissed.
    func isFilterRelatedSheet(_ sheet: AppSheetType) -> Bool {
        switch sheet {
        case .list, .externalVideos, .reviews, .favorites, .myPlaces,
             .externalReviews, .externalList, .externalFavorites,
             .keywordResults, .nearbyDiscovery:
            return true
        default:
            return false
        }
    }

    /// Clears all special filters (list, external places, reviews, favorites, my places, external).
    func clearAllFilters() {
        filteringViewModel.clearAllFilters()
        externalUserViewModel.clearAllFilters()
        viewportViewModel.clearAnnotations()
        viewportViewModel.resetLastLoadedRegion()
        // Note: activeSheet is NOT cleared here - it's managed by the sheet presentation logic
    }

    /// Clears only the current user's filters without affecting external user filters.
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

    /// Called when the map camera has settled. Routes to city or place annotations based on zoom level.
    func onMapCameraSettled(_ newRegion: MKCoordinateRegion, userId: String) async {
        let filterState = buildFilterState()
        let shouldShowCities = MapCityAnnotationViewModel.shouldShowCityAnnotations(
            latitudeDelta: newRegion.span.latitudeDelta,
            isCurrentlyShowingCities: showingCityAnnotations
        )

        if shouldShowCities && !filterState.hasActiveFilter {
            // Zoomed out + no filter → show city annotations
            if !showingCityAnnotations {
                showingCityAnnotations = true
                viewportViewModel.clearAnnotations()
            }
            await cityAnnotationViewModel.fetchCityAnnotations(region: newRegion, userId: userId)
        } else {
            // Zoomed in or filter active → show place annotations
            if showingCityAnnotations {
                showingCityAnnotations = false
                cityAnnotationViewModel.clearAnnotations()
            }
            await viewportViewModel.onMapCameraSettled(newRegion, userId: userId, filterState: filterState)
        }
    }

    /// Filters annotations for current viewport.
    func getAnnotationsForViewport(_ region: MKCoordinateRegion) -> [PlaceAnnotation] {
        return viewportViewModel.getAnnotationsForViewport(region)
    }

    /// Returns all place annotations to display on map.
    func getAllDisplayAnnotations() -> [PlaceAnnotation] {
        return viewportViewModel.getAllDisplayAnnotations()
    }

    // MARK: - City Annotation Tap (Delegated)

    /// Handles tap on a city annotation by cancelling any in-flight discovery and presenting the city detail sheet.
    func handleCityAnnotationTap(_ city: CityAnnotation) {
        tapDiscoveryViewModel.resetState()
        PresentationService.shared.present(.cityOverview(cityName: city.name, coordinate: city.coordinate, annotation: city))
    }

    // MARK: - Tap Discovery (Delegated)

    /// Discovers the nearest POI at the given coordinate via MKLocalSearch and backend resolution.
    func discoverPlaceAtCoordinate(_ coordinate: CLLocationCoordinate2D) {
        tapDiscoveryViewModel.discoverPlace(at: coordinate)
    }

    // MARK: - Private Helpers

    /// Builds the current filter state from child ViewModels.
    private func buildFilterState() -> MapFilterState {
        return MapFilterState(
            selectedListId: filteringViewModel.selectedListId,
            showingExternalPlacesOnMap: filteringViewModel.showingExternalPlacesOnMap,
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
