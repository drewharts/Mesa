//
//  ExploreNavigationViewModel.swift
//  loc
//
//  Owns the Explore sheet's navigation path and keeps the map in step with it: while a list is on the path
//  the map shows that list's pins (the sheet lowers to medium); popping back to Explore clears them.
//

import Foundation

@MainActor
final class ExploreNavigationViewModel: ObservableObject {

    // MARK: - Published State

    @Published var path: [ExploreDestination] = []

    // MARK: - Private State

    private weak var mapCoordinator: MapDisplayCoordinatorViewModel?
    private weak var tabSheet: TabSheetViewModel?
    private let listSheetViewModel = ListMapSheetViewModel.shared
    private let presentationService = PresentationService.shared
    private var pinnedListId: String?
    private var isActive = true

    /// The list closest to the top of the path, if any.
    private var activeList: ExploreList? {
        for destination in path.reversed() {
            if case .list(let list, _) = destination { return list }
        }
        return nil
    }

    // MARK: - Setup

    /// Connects the map coordinator that shows and clears list pins, and the sheet whose header strip follows the path.
    func bind(mapCoordinator: MapDisplayCoordinatorViewModel, tabSheet: TabSheetViewModel) {
        self.mapCoordinator = mapCoordinator
        self.tabSheet = tabSheet
    }

    // MARK: - Header

    /// Shows the destination on top of the path in the sheet's header strip (ignored once the path is back at the root).
    func setHeader(_ header: TabSheetHeader) {
        guard !path.isEmpty else { return }
        tabSheet?.setPushedHeader(header)
    }

    /// Pops the destination on top of the path.
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Restores the plain "Explore" strip once nothing is pushed.
    func clearHeaderIfAtRoot() {
        if path.isEmpty { tabSheet?.setPushedHeader(nil) }
    }

    // MARK: - Pushing

    /// Pushes a city's lists.
    func openCity(_ city: ExploreCity) {
        path.append(.city(city))
    }

    /// Pushes a list; with `startFindTable` its "Find a table" form opens once the list is on screen.
    func openList(_ list: ExploreList, startFindTable: Bool = false) {
        if startFindTable { listSheetViewModel.requestFindTable(listId: list.id) }
        path.append(.list(list, startFindTable: startFindTable))
    }

    /// Pushes a place's detail page.
    func openPlace(_ placeId: String) {
        path.append(.place(placeId))
    }

    /// Pushes another user's profile.
    func openProfile(_ profile: ProfileData) {
        path.append(.user(profile))
    }

    // MARK: - Map Pins

    /// Pins or unpins the map's list filter so it matches the list on top of the path (call whenever the path changes).
    func syncMapWithPath() {
        let list = isActive ? activeList : nil
        guard list?.id != pinnedListId else { return }
        if let pinnedListId { listSheetViewModel.cancelFindTableRequest(for: pinnedListId) }
        pinnedListId = list?.id
        if let list {
            pin(list)
        } else {
            mapCoordinator?.clearTabListPins()
            listSheetViewModel.endSession()
        }
    }

    /// Starts the list's map session and asks the map to show only its pins.
    private func pin(_ list: ExploreList) {
        listSheetViewModel.beginSession(listId: list.id, placeCount: list.placeCount, isExternal: true, source: "explore_push")
        mapCoordinator?.showTabListPins(.init(listId: list.id, ownerId: list.ownerId, ownerPhotoUrl: list.ownerPhotoURL))
    }

    /// Drops the map pins while another tab is showing and restores them when Explore returns (the path is kept).
    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        syncMapWithPath()
    }

    /// Opens the place behind a tapped map pin (replacing a place page that is already on top) while a list is pushed.
    func handleMapPinTap(_ placeId: String) {
        guard isActive, activeList != nil else { return }
        presentationService.pendingPlaceNavigation = nil
        if case .place? = path.last { path.removeLast() }
        path.append(.place(placeId))
    }
}
