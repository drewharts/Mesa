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

    /// True/false once known whether any place has a Resy venue; nil while the lookup is pending.
    @Published private(set) var hasReservablePlaces: Bool?

    /// Opens "Find a table" for this list; nil while the button shouldn't show in the header.
    private var findTableAction: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()
    private var hasLoaded = false

    /// Places loaded for this list.
    var places: [LightweightPlace] { popup.currentPlaces }

    /// "N places" label that follows the selected tag chip.
    var countLabel: String {
        let count = sheet.headerPlaceCount(total: popup.displayedPlaceCount)
        return "\(count) place\(count == 1 ? "" : "s")"
    }

    /// True when the list belongs to the signed-in user.
    func isOwnList(currentUserId: String?) -> Bool {
        guard let currentUserId else { return false }
        return currentUserId.caseInsensitiveCompare(list.ownerId) == .orderedSame
    }

    /// The creator as a profile stub; the profile screen refreshes the full record when it opens.
    var ownerProfile: ProfileData? {
        guard let name = list.ownerName, !name.isEmpty else { return nil }
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        return ProfileData(
            id: list.ownerId,
            firstName: parts.first ?? name,
            lastName: parts.count > 1 ? parts[1] : "",
            email: "",
            profilePhotoURL: list.ownerPhotoURL.flatMap { URL(string: $0) },
            fullName: name
        )
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
        async let reservable = ExploreListsService.shared.listHasReservablePlaces(listId: list.id)
        await popup.loadPlacesIfNeeded()
        sheet.fitToPlaces(places)
        placeMeta.prefetchCities(for: places)
        hasReservablePlaces = await reservable ?? true
    }

    /// Whether the header shows the "Find a table" button.
    var showsFindTable: Bool { findTableAction != nil }

    /// Stores the action the list view offers for "Find a table" (nil hides the header button).
    func setFindTableAction(_ action: (() -> Void)?) {
        findTableAction = action
        objectWillChange.send()
    }

    /// Builds the header the sheet's strip shows for this list: title, creator chip (tappable unless it's the user's own list), count, share.
    func header(
        currentUserId: String?,
        onBack: @escaping () -> Void,
        onOpenProfile: @escaping (ProfileData) -> Void
    ) -> TabSheetHeader {
        TabSheetHeader(
            id: "list-\(list.id)",
            title: list.name,
            creator: creator(currentUserId: currentUserId, onOpenProfile: onOpenProfile),
            detail: countLabel,
            onBack: onBack,
            onShare: { [weak self] in self?.shareList() },
            onFindTable: findTableAction
        )
    }

    /// The creator chip content: "You" for the user's own list (not tappable), else the owner's name linking to their profile.
    private func creator(currentUserId: String?, onOpenProfile: @escaping (ProfileData) -> Void) -> TabSheetHeader.Creator? {
        if isOwnList(currentUserId: currentUserId) {
            return .init(name: "You", photoURL: list.ownerPhotoURL, onTap: nil)
        }
        guard let name = list.ownerName, !name.isEmpty else { return nil }
        var onTap: (() -> Void)?
        if let profile = ownerProfile { onTap = { onOpenProfile(profile) } }
        return .init(
            name: ScreenshotPrivacy.name(name, userId: list.ownerId),
            photoURL: ScreenshotPrivacy.photoURL(list.ownerPhotoURL, userId: list.ownerId),
            onTap: onTap
        )
    }

    /// Opens the system share sheet for the list.
    func shareList() {
        let shareable = Self.lightweightList(from: list)
        ServiceContainer.shared.placeShareService.shareLightweightList(shareable, userId: list.ownerId)
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
