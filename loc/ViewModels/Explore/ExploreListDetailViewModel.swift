//
//  ExploreListDetailViewModel.swift
//  loc
//
//  Loads a pushed Explore list's places and drives the map-first behaviour (framing the pins, focusing
//  a tapped place) through the shared list-sheet view model, reusing the external list popup's loading.
//

import Foundation
import Combine

@MainActor
final class ExploreListDetailViewModel: ObservableObject {

    // MARK: - State

    let list: ExploreList
    let popup: ExternalListPopupViewModel
    let sheet = ListMapSheetViewModel.shared
    let placeMeta = ListPlaceMetaStore.shared

    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    /// Places loaded for this list.
    var places: [LightweightPlace] { popup.currentPlaces }

    /// "N places" label that follows the selected tag chip.
    var countLabel: String {
        let count = sheet.headerPlaceCount(total: popup.displayedPlaceCount)
        return "\(count) place\(count == 1 ? "" : "s")"
    }

    // MARK: - Initialization

    /// Creates the view model for one list and republishes changes from the objects it reads.
    init(list: ExploreList) {
        self.list = list
        self.popup = ExternalListPopupViewModel(lists: [Self.lightweightList(from: list)], initialListIndex: 0)
        popup.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        sheet.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        placeMeta.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    /// Builds the lightweight list the shared list popup logic expects from an Explore list.
    private static func lightweightList(from list: ExploreList) -> LightweightPlaceList {
        LightweightPlaceList(
            list_id: list.id,
            name: list.name,
            is_public: true,
            image: list.imageURL,
            created_at: list.createdAt,
            updated_at: list.updatedAt,
            distance_meters: nil,
            place_count: list.placeCount,
            city: list.city,
            owner_name: list.ownerName,
            owner_photo_url: list.ownerPhotoURL
        )
    }

    // MARK: - Loading

    /// Loads the list's places once, then frames the map on their pins.
    func load() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await popup.loadPlacesIfNeeded()
        sheet.fitToPlaces(places)
        placeMeta.prefetchCities(for: places)
    }

    /// Frames all of the list's pins again after returning from a place page.
    func reframePins() {
        guard hasLoaded else { return }
        sheet.refitToPlaces(places)
    }

    // MARK: - Row Actions

    /// Focuses a tapped place's pin above the sheet, then asks the caller to open its page.
    func select(_ place: LightweightPlace, open: (String) -> Void) {
        sheet.focus(place: place, source: .row)
        open(place.place_id)
    }

    /// Returns the neighborhood/city line for a place row, if known.
    func locationText(for placeId: String) -> String? {
        placeMeta.location(for: placeId)
    }

    /// Requests the neighborhood line for a row that scrolled into view.
    func rowAppeared(_ place: LightweightPlace) {
        placeMeta.requestNeighborhood(for: place)
    }
}
