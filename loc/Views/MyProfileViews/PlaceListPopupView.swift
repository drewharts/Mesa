//
//  PlaceListPopupView.swift
//  loc
//
//  Reusable Component: Generic popup container for displaying paginated place lists
//  Used by: ExternalPlacesPopupView, ReviewsListPopupView, and future popup views
//  DUMB Component: Pure display, all data provided via parameters
//
//  Usage:
//  PlaceListPopupView(
//      title: "Saved Videos",
//      count: profile.totalExternalPlacesCount,
//      isLoading: profile.isLoadingExternalPlaces,
//      isLoadingMore: profile.isLoadingMoreExternalPlaces,
//      places: profile.lightweightExternalPlaces,
//      hasMore: profile.hasMoreExternalPlaces,
//      emptyIcon: "video",
//      emptyTitle: "No Videos Yet",
//      emptyMessage: "Places you add from videos will appear here",
//      loadMore: { await profile.loadMoreExternalPlaces() },
//      cardBuilder: { place, navigate in PopupPlaceCard(place: place, onNavigate: navigate, ...) }
//  )

import SwiftUI
import Combine

struct PlaceListPopupView<CardView: View, HeaderAccessory: View>: View {
    // MARK: - Configuration
    let title: String
    let count: Int?
    let isLoading: Bool
    let isLoadingMore: Bool
    let places: [LightweightPlace]
    let hasMore: Bool
    let emptyIcon: String
    let emptyTitle: String
    let emptyMessage: String
    let loadMore: () async -> Void
    let onBackToProfile: (() -> Void)?  // Optional: Shows "Profile" button when provided
    let onViewOnMap: (() -> Void)?  // Optional: Shows "Map" button when provided
    @ViewBuilder let cardBuilder: (LightweightPlace, @escaping (String) -> Void) -> CardView
    @ViewBuilder let headerAccessory: () -> HeaderAccessory
    /// Optional destructive action offered on each tile's long-press menu.
    let onRemove: ((LightweightPlace) -> Void)?
    /// Whether opening the sheet fits the map to the places' pins (off for region-driven filters like "Nearby").
    let fitsMapToPlaces: Bool

    @Environment(\.presentationMode) var presentationMode

    /// Observed for pending place navigation when map annotation is tapped while sheet is open.
    @ObservedObject private var presentationService = PresentationService.shared

    /// Initializes the popup view with all configuration options.
    init(
        title: String,
        count: Int? = nil,
        isLoading: Bool,
        isLoadingMore: Bool,
        places: [LightweightPlace],
        hasMore: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        loadMore: @escaping () async -> Void,
        onBackToProfile: (() -> Void)? = nil,
        onViewOnMap: (() -> Void)? = nil,
        @ViewBuilder cardBuilder: @escaping (LightweightPlace, @escaping (String) -> Void) -> CardView,
        @ViewBuilder headerAccessory: @escaping () -> HeaderAccessory,
        onRemove: ((LightweightPlace) -> Void)? = nil,
        fitsMapToPlaces: Bool = true
    ) {
        self.onRemove = onRemove
        self.fitsMapToPlaces = fitsMapToPlaces
        self.title = title
        self.count = count
        self.isLoading = isLoading
        self.isLoadingMore = isLoadingMore
        self.places = places
        self.hasMore = hasMore
        self.emptyIcon = emptyIcon
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.loadMore = loadMore
        self.onBackToProfile = onBackToProfile
        self.onViewOnMap = onViewOnMap
        self.cardBuilder = cardBuilder
        self.headerAccessory = headerAccessory
    }

    // Navigation state for place detail navigation
    @State private var navigationPath = NavigationPath()

    /// Shared map-first sheet state (detent, focused pin, camera), same as list sheets.
    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared
    @ObservedObject private var placeMeta = ListPlaceMetaStore.shared

    /// Session key for analytics / sheet state (sections are not real lists).
    private var sessionId: String { "section:\(title)" }

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                header
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { placeId in
                PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: true)
                    .id(placeId)
            }
        }
        .onReceive(presentationService.$pendingPlaceNavigation.compactMap { $0 }) { placeId in
            // Map pin tapped while the sheet is open: highlight/scroll to its tile;
            // a second tap (or a tap while a place page is open) opens that place.
            presentationService.pendingPlaceNavigation = nil
            handleMapPinTap(placeId)
        }
        .onAppear {
            sheetVM.beginSession(listId: sessionId, placeCount: count ?? places.count, isExternal: false, source: "profile_section")
            fitMapIfNeeded()
        }
        .onChange(of: places.count) { _, _ in fitMapIfNeeded() }
        .onDisappear { sheetVM.endSession() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                // Back button on left (external profile popups only)
                if let backAction = onBackToProfile {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                        backAction()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 44, height: 44)
                }

                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Spacer()

                // Header accessory inline (e.g. filter buttons)
                headerAccessory()

                // Close button on right (current user popups only)
                if onBackToProfile == nil {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.primary)
                    }
                    .frame(width: 44, height: 44)
                }
            }

            if let count = count {
                Text("\(count) place\(count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, -8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !isLoading && places.isEmpty {
            emptyView
        } else {
            ListPlacesScrollView(
                places: places,
                isLoadingInitial: isLoading && places.isEmpty,
                isLoadingMore: isLoadingMore && !places.isEmpty,
                showAddedBy: false,
                focusedPlaceId: sheetVM.focusedPlaceId,
                scrollRequest: sheetVM.scrollRequest,
                locationText: { placeMeta.location(for: $0) },
                onRowAppear: { placeMeta.requestNeighborhood(for: $0) },
                onLoadMore: {
                    guard hasMore && !isLoadingMore else { return }
                    Task { await loadMore() }
                },
                onSelect: { handleTileTap($0) },
                onOpenDetail: { openPlaceDetail($0) },
                onRemove: removeHandler
            )
        }
    }

    /// Adapts the place-based remove action to the id-based tile menu.
    private var removeHandler: ((String) -> Void)? {
        guard let onRemove else { return nil }
        return { placeId in
            if let place = place(withId: placeId) { onRemove(place) }
        }
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: emptyIcon)
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))
            Text(emptyTitle)
                .font(.headline)
                .foregroundColor(.secondary)
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Map-First Actions

    private func place(withId placeId: String) -> LightweightPlace? {
        places.first { $0.place_id.caseInsensitiveCompare(placeId) == .orderedSame }
    }

    private func hasCoordinate(_ place: LightweightPlace) -> Bool {
        guard let lat = place.latitude, let lon = place.longitude else { return false }
        return !(lat == 0 && lon == 0)
    }

    private func fitMapIfNeeded() {
        guard fitsMapToPlaces, !places.isEmpty else { return }
        sheetVM.fitToPlaces(places)
        placeMeta.prefetchCities(for: places)
    }

    /// Tile tap: select and center its pin; a second tap opens the place.
    /// Places without coordinates (e.g. some videos) have no pin, so they open directly.
    private func handleTileTap(_ place: LightweightPlace) {
        if sheetVM.isFocused(place.place_id) || !hasCoordinate(place) {
            openPlaceDetail(place)
        } else {
            sheetVM.focus(place: place, source: .row)
        }
    }

    private func openPlaceDetail(_ place: LightweightPlace) {
        replaceDetail(with: place.place_id)
    }

    private func handleMapPinTap(_ placeId: String) {
        guard navigationPath.isEmpty, let tapped = place(withId: placeId) else {
            if let tapped = place(withId: placeId) { sheetVM.focus(place: tapped, source: .pin) }
            replaceDetail(with: placeId)
            return
        }
        if sheetVM.isFocused(tapped.place_id) {
            replaceDetail(with: tapped.place_id)
        } else {
            sheetVM.focus(place: tapped, source: .pin)
        }
    }

    private func replaceDetail(with placeId: String) {
        sheetVM.ensureAtLeastHalf()
        var newPath = NavigationPath()
        newPath.append(placeId)
        navigationPath = newPath
    }
}

// MARK: - Convenience Init (No Header Accessory)

extension PlaceListPopupView where HeaderAccessory == EmptyView {
    /// Convenience initializer without header accessory (backward compatible).
    init(
        title: String,
        count: Int? = nil,
        isLoading: Bool,
        isLoadingMore: Bool,
        places: [LightweightPlace],
        hasMore: Bool,
        emptyIcon: String,
        emptyTitle: String,
        emptyMessage: String,
        loadMore: @escaping () async -> Void,
        onBackToProfile: (() -> Void)? = nil,
        onViewOnMap: (() -> Void)? = nil,
        @ViewBuilder cardBuilder: @escaping (LightweightPlace, @escaping (String) -> Void) -> CardView,
        onRemove: ((LightweightPlace) -> Void)? = nil
    ) {
        self.init(
            title: title,
            count: count,
            isLoading: isLoading,
            isLoadingMore: isLoadingMore,
            places: places,
            hasMore: hasMore,
            emptyIcon: emptyIcon,
            emptyTitle: emptyTitle,
            emptyMessage: emptyMessage,
            loadMore: loadMore,
            onBackToProfile: onBackToProfile,
            onViewOnMap: onViewOnMap,
            cardBuilder: cardBuilder,
            headerAccessory: { EmptyView() },
            onRemove: onRemove
        )
    }
}
