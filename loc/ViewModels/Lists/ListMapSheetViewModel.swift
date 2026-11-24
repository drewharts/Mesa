//
//  ListMapSheetViewModel.swift
//  loc
//
//  Coordinates the map-first list experience: the full-screen map shows the list's pins while
//  the list sits in a three-height bottom sheet. This view model owns the sheet height, which
//  place is focused (row tap or pin tap), and the camera requests the map should apply.
//  Views stay dumb: the sheet, rows and map only read this state and forward user intents.
//

import Foundation
import MapKit
import SwiftUI
import CoreLocation

@MainActor
final class ListMapSheetViewModel: ObservableObject {
    static let shared = ListMapSheetViewModel()

    // MARK: - Types

    /// Where a focus change originated.
    enum FocusSource: String {
        case row
        case pin
    }

    /// What the map should do with its camera.
    enum CameraTarget {
        /// Fit a whole region (all of the list's pins).
        case region(MKCoordinateRegion)
        /// Center a single coordinate in the part of the map not covered by the sheet.
        case point(CLLocationCoordinate2D, sheetFraction: CGFloat)
    }

    /// A one-shot camera instruction. `id` makes every request distinct so the map reacts to repeats.
    struct CameraRequest: Equatable {
        let id = UUID()
        let target: CameraTarget

        static func == (lhs: CameraRequest, rhs: CameraRequest) -> Bool { lhs.id == rhs.id }
    }

    /// A one-shot request for the sheet to scroll a row into view.
    struct ScrollRequest: Equatable {
        let id = UUID()
        let placeId: String

        static func == (lhs: ScrollRequest, rhs: ScrollRequest) -> Bool { lhs.id == rhs.id }
    }

    /// A one-shot request (from Explore) to open the "Find a table" form once the list's sheet is showing.
    struct FindTableRequest: Equatable {
        let listId: String
        let requestedAt: Date
    }

    // MARK: - Published State

    @Published private(set) var detent: ListSheetDetent = .default
    @Published private(set) var focusedPlaceId: String?
    @Published private(set) var cameraRequest: CameraRequest?
    @Published private(set) var scrollRequest: ScrollRequest?
    /// Ids (lowercased) of the places the selected tag chip keeps; nil means "All" (nothing filtered).
    /// The map shows only these pins and the sheet header counts them.
    @Published private(set) var chipScopeIds: Set<String>?

    /// Pending "Find a table" start for a list that is about to open (or is already open).
    @Published private(set) var findTableRequest: FindTableRequest?

    // MARK: - Private State

    private let findTableRequestLifetime: TimeInterval = 45
    private var listId: String?
    private var hasFitMap = false

    private init() {}

    // MARK: - Session

    /// Starts a session for a list that just opened. Resets focus and height, and tracks the open.
    func beginSession(listId: String, placeCount: Int, isExternal: Bool, source: String) {
        guard self.listId != listId else { return }
        self.listId = listId
        hasFitMap = false
        focusedPlaceId = nil
        scrollRequest = nil
        chipScopeIds = nil
        detent = .default
        Analytics.track(.listOpened, [
            "list_id": listId,
            "place_count": placeCount,
            "is_external": isExternal,
            "source": source,
            "detent": ListSheetDetent.default.rawValue
        ])
    }

    /// Ends the session when the list sheet goes away.
    func endSession() {
        listId = nil
        hasFitMap = false
        focusedPlaceId = nil
        scrollRequest = nil
        chipScopeIds = nil
        detent = .default
    }

    // MARK: - Find a Table Handoff

    /// Asks the list sheet for `listId` to open its "Find a table" form as soon as it shows.
    /// The request stays pending until a list view reports it presented the form (see `completeFindTableRequest`).
    func requestFindTable(listId: String) {
        FindTableLog.log("request armed for list \(listId.lowercased())")
        findTableRequest = FindTableRequest(listId: listId.lowercased(), requestedAt: Date())
    }

    /// Whether a fresh request targets this list; expired requests are dropped. Does not consume the request,
    /// so a list view that is torn down before presenting the form leaves it for the next one.
    func hasFindTableRequest(for listId: String) -> Bool {
        guard let request = findTableRequest else { return false }
        guard Date().timeIntervalSince(request.requestedAt) < findTableRequestLifetime else {
            FindTableLog.log("request for \(request.listId) expired before a list view handled it")
            findTableRequest = nil
            return false
        }
        return request.listId == listId.lowercased()
    }

    /// Consumes the pending request for `listId` once its form has been shown.
    func completeFindTableRequest(for listId: String) {
        guard findTableRequest?.listId == listId.lowercased() else { return }
        FindTableLog.log("request for \(listId.lowercased()) completed")
        findTableRequest = nil
    }

    /// Drops the pending request for `listId` because the list could not be shown.
    func cancelFindTableRequest(for listId: String) {
        guard findTableRequest?.listId == listId.lowercased() else { return }
        FindTableLog.log("request for \(listId.lowercased()) cancelled")
        findTableRequest = nil
    }

    // MARK: - Chip Scope

    /// Publishes the places the selected chip keeps (nil restores all). Unchanged sets are ignored so the
    /// map and header are not re-rendered for no-op updates.
    func setChipScope(_ ids: Set<String>?) {
        guard ids != chipScopeIds else { return }
        chipScopeIds = ids
    }

    /// The place count the header shows: the selected chip's count, or `total` on "All".
    func headerPlaceCount(total: Int) -> Int {
        chipScopeIds?.count ?? total
    }

    // MARK: - Sheet Height

    /// Called when the user drags the sheet to a new height.
    func userChangedDetent(_ presentationDetent: PresentationDetent) {
        guard let newDetent = ListSheetDetent(presentationDetent) else { return }
        applyDetent(newDetent, trigger: "drag")
    }

    /// Moves the sheet programmatically (for example to make room for a selected row).
    func requestDetent(_ newDetent: ListSheetDetent, trigger: String) {
        applyDetent(newDetent, trigger: trigger)
    }

    private func applyDetent(_ newDetent: ListSheetDetent, trigger: String) {
        guard newDetent != detent else { return }
        let previous = detent
        detent = newDetent
        Analytics.track(.listSheetHeightChanged, [
            "list_id": listId ?? "",
            "from": previous.rawValue,
            "to": newDetent.rawValue,
            "trigger": trigger
        ])
    }

    // MARK: - Focus

    /// Whether the given place is the currently focused one (case-insensitive id match).
    func isFocused(_ placeId: String) -> Bool {
        guard let focusedPlaceId else { return false }
        return focusedPlaceId.caseInsensitiveCompare(placeId) == .orderedSame
    }

    /// Focuses a place: highlights its row and pin and centers the pin above the sheet.
    /// A pin tap scrolls the row into view; a row tap does not need to.
    func focus(place: LightweightPlace, source: FocusSource) {
        focusedPlaceId = place.place_id

        // Keep both the tile and the pin visible. The peek detent shows a tile row, so it stays put;
        // a tile tap at full drops to half so the pin is visible.
        switch (source, detent) {
        case (.row, .full):
            applyDetent(.half, trigger: "row_tap")
        default:
            break
        }

        if source == .pin {
            scrollRequest = ScrollRequest(placeId: place.place_id)
        }

        if let latitude = place.latitude, let longitude = place.longitude {
            let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            cameraRequest = CameraRequest(target: .point(coordinate, sheetFraction: detent.screenFraction))
        }

        Analytics.track(.listPlaceSelected, [
            "list_id": listId ?? "",
            "place_id": place.place_id,
            "source": source.rawValue
        ])
    }

    /// Clears the focused place.
    func clearFocus() {
        focusedPlaceId = nil
    }

    /// Makes sure the sheet is at least half height (used before showing a place detail inside it).
    func ensureAtLeastHalf() {
        if detent == .peek {
            applyDetent(.half, trigger: "open_detail")
        }
    }

    // MARK: - Fit To Pins

    /// Fits the map to all of the list's pins. Runs once per session and never overrides
    /// a place the user has already focused.
    /// Frames a precomputed region (e.g. from ImportsMapFraming), offset so it sits above the half-height sheet.
    func fitToRegion(_ region: MKCoordinateRegion) {
        guard focusedPlaceId == nil else { return }
        hasFitMap = true
        let latSpan = region.span.latitudeDelta
        let sheetFraction = Double(ListSheetDetent.default.screenFraction)
        let totalLatSpan = min(latSpan / max(1 - sheetFraction, 0.3), 170)
        let centerLat = region.center.latitude - (totalLatSpan - latSpan) / 2
        let adjusted = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: min(max(centerLat, -85), 85),
                longitude: min(max(region.center.longitude, -179.9), 179.9)
            ),
            span: MKCoordinateSpan(latitudeDelta: totalLatSpan, longitudeDelta: min(region.span.longitudeDelta, 350))
        )
        cameraRequest = CameraRequest(target: .region(adjusted))
    }

    func fitToPlaces(_ places: [LightweightPlace]) {
        guard !hasFitMap, focusedPlaceId == nil else { return }
        let coordinates = places.compactMap { place -> CLLocationCoordinate2D? in
            guard let latitude = place.latitude, let longitude = place.longitude,
                  abs(latitude) <= 90, abs(longitude) <= 180,
                  !(latitude == 0 && longitude == 0) else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        guard !coordinates.isEmpty else { return }
        hasFitMap = true

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0

        // Pad the span, enforce a sensible minimum zoom, and extend the south edge so the pins
        // sit in the part of the map above the half-height sheet.
        let padding = 1.4
        let latSpan = max((maxLat - minLat) * padding, 0.01)
        let lonSpan = max((maxLon - minLon) * padding, 0.01)
        let sheetFraction = Double(ListSheetDetent.default.screenFraction)
        let totalLatSpan = min(latSpan / max(1 - sheetFraction, 0.3), 170)
        let centerLat = (minLat + maxLat) / 2 - (totalLatSpan - latSpan) / 2
        let centerLon = (minLon + maxLon) / 2

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: min(max(centerLat, -85), 85),
                longitude: min(max(centerLon, -179.9), 179.9)
            ),
            span: MKCoordinateSpan(latitudeDelta: totalLatSpan, longitudeDelta: min(lonSpan, 350))
        )
        cameraRequest = CameraRequest(target: .region(region))
    }
}
