//
//  ListPlacesScrollView.swift
//  loc
//
//  Places of the map-first list sheet, rendered as large square photo tiles.
//  Collapsed (peek) detent: one horizontal row of tiles. Half/full: a 2-column grid
//  matching the pre-map-first list popup. Handles shimmer skeletons, empty state, pagination
//  and scrolling a tile into view when its pin is tapped. All actions are closures.
//

import SwiftUI

struct ListPlacesScrollView: View {
    let places: [LightweightPlace]
    let isLoadingInitial: Bool
    let isLoadingMore: Bool
    let showAddedBy: Bool
    let focusedPlaceId: String?
    let scrollRequest: ListMapSheetViewModel.ScrollRequest?
    let locationText: (String) -> String?
    let onRowAppear: (LightweightPlace) -> Void
    let onLoadMore: () -> Void
    let onSelect: (LightweightPlace) -> Void
    let onOpenDetail: (LightweightPlace) -> Void
    /// Optional destructive action (own lists only).
    let onRemove: ((String) -> Void)?
    /// Shows the tag chips (All, Sushi, Coffee, ...) above the places. Off for the map's "Places here" sheet.
    var showsTypeFilter: Bool = false
    /// The list being shown; with `showsTypeFilter` it lets the chips cover every place in the list.
    var listId: String? = nil
    /// Loads every remaining place of the list so a selected chip shows all of its matches.
    var onLoadAll: (() async -> Void)? = nil

    @StateObject private var filterVM = ListTypeFilterViewModel()
    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared

    static let rowTileSize: CGFloat = 150

    private let columns = [
        GridItem(.flexible(), spacing: 12, alignment: .top),
        GridItem(.flexible(), spacing: 12, alignment: .top)
    ]

    private var isCollapsed: Bool { sheetVM.detent == .peek }

    /// Side of a square tile in points, used to warm images at the size the tiles will request.
    private var tileSide: CGFloat {
        isCollapsed ? Self.rowTileSize : ListTypeFilterViewModel.gridTileSide(screenWidth: UIScreen.main.bounds.width)
    }

    /// The chip row, or nothing when filtering is off or the list has too few tags.
    @ViewBuilder
    private func typeFilterRow(display: ListTypeFilterViewModel.Display) -> some View {
        if display.showsFilterRow {
            ListTypeFilterRow(
                chips: display.chips,
                isSelected: { filterVM.isSelected($0) },
                onSelect: { chip in withAnimation(.easeInOut(duration: 0.2)) { filterVM.handleChipTap(chip) } },
                isSearching: filterVM.isSearching,
                searchQuery: Binding(get: { filterVM.searchQuery }, set: { filterVM.setSearchQuery($0) }),
                onBeginSearch: { filterVM.beginSearch() },
                onClearOrCloseSearch: { filterVM.clearOrCloseSearch() },
                onCollapseSearch: { filterVM.endSearch() }
            )
            .padding(.vertical, 4)
        }
    }

    private func isSelected(_ place: LightweightPlace) -> Bool {
        guard let focusedPlaceId else { return false }
        return focusedPlaceId.caseInsensitiveCompare(place.place_id) == .orderedSame
    }

    var body: some View {
        // Chips, de-duplicated tiles and load-more ids are memoized in the view model: computed once per render.
        let display = filterVM.display(for: places, filtersByType: showsTypeFilter)
        return ScrollViewReader { proxy in
            Group {
                if places.isEmpty && !isLoadingInitial {
                    Text("No places in this list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if display.tiles.isEmpty && !isLoadingInitial && !filterVM.isLoadingMatches {
                    ListFilterEmptyState(loadFailed: filterVM.matchesLoadFailed, message: filterVM.hasSearchQuery ? "No places match your search" : nil) {
                        Task { await filterVM.loadMatchesIfNeeded(loaded: { places }, loadAll: { await onLoadAll?() }) }
                    }
                } else if isCollapsed {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            content(display, tileWidth: Self.rowTileSize)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            content(display, tileWidth: nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .transition(.opacity)
                }
            }
            .safeAreaInset(edge: .top, spacing: 8) { typeFilterRow(display: display) }
            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
            // A narrower filter may leave too few tiles to scroll; ask for the next page so more can match.
            .onChange(of: filterVM.selection) { _, _ in
                filterVM.beginLoadingMatchesIfNeeded(loaded: places)
                filterVM.prefetchImages(for: display.tiles, tileSide: tileSide)
                if filterVM.mayHaveUnloadedMatches(loaded: places) { onLoadMore() }
                Task { await filterVM.loadMatchesIfNeeded(loaded: { places }, loadAll: { await onLoadAll?() }) }
            }
            // Typing narrows the list instantly from memory; paging in unloaded matches waits for a pause in typing.
            .onChange(of: filterVM.searchQuery) { _, _ in filterVM.beginLoadingMatchesIfNeeded(loaded: places) }
            .task(id: filterVM.searchQuery) {
                guard filterVM.hasSearchQuery else { return }
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                filterVM.prefetchImages(for: display.tiles, tileSide: tileSide)
                if filterVM.mayHaveUnloadedMatches(loaded: places) { onLoadMore() }
                Task { await filterVM.loadMatchesIfNeeded(loaded: { places }, loadAll: { await onLoadAll?() }) }
            }
            .task(id: places.count) {
                guard showsTypeFilter, let listId else { return }
                await filterVM.refreshTagSource(listId: listId, loaded: places)
                // The whole-list index may arrive after a chip was tapped; load that chip's missing places now.
                // Unstructured: a changing place count restarts this task and must not cancel the network load.
                Task { await filterVM.loadMatchesIfNeeded(loaded: { places }, loadAll: { await onLoadAll?() }) }
            }
            .onAppear {
                for p in places { if let la = p.latitude, let lo = p.longitude {
                    PlaceTimeZoneCache.shared.registerCoordinate(placeId: p.place_id, latitude: la, longitude: lo)
                } }
                PlaceHoursStore.shared.prefetch(places.map(\.place_id))
            }
            .onChange(of: places.count) { _, _ in
                PlaceHoursStore.shared.prefetch(places.map(\.place_id))
                if filterVM.selection != nil { filterVM.prefetchImages(for: display.tiles, tileSide: tileSide) }
            }
            // The map behind the sheet and the header count follow the selected chip.
            .onChange(of: display.scopeIds) { _, ids in sheetVM.setChipScope(ids) }
            .onDisappear { sheetVM.setChipScope(nil) }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }
                scroll(proxy, to: request.placeId, delay: 250_000_000)
            }
            .onChange(of: isCollapsed) { _, _ in
                // Keep the selected tile visible when the layout switches between row and grid.
                if let focusedPlaceId {
                    scroll(proxy, to: focusedPlaceId, delay: 350_000_000)
                }
            }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to placeId: String, delay: UInt64) {
        let anchor: UnitPoint = .center
        Task {
            try? await Task.sleep(nanoseconds: delay)
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(placeId, anchor: anchor)
            }
        }
    }

    @ViewBuilder
    private func content(_ display: ListTypeFilterViewModel.Display, tileWidth: CGFloat?) -> some View {
        if places.isEmpty {
            ForEach(0..<6, id: \.self) { _ in
                ListPlaceTileSkeleton(width: tileWidth)
            }
        } else {
            ForEach(display.tiles) { place in
                ListPlaceTileView(
                    place: place,
                    locationText: locationText(place.place_id),
                    isSelected: isSelected(place),
                    showAddedBy: showAddedBy,
                    width: tileWidth,
                    onTap: { onSelect(place) }
                )
                .id(place.place_id)
                .transition(.opacity)
                .contextMenu {
                    Button {
                        onOpenDetail(place)
                    } label: {
                        Label("Open place", systemImage: "arrow.up.right")
                    }
                    if let onRemove {
                        Button(role: .destructive) {
                            onRemove(place.place_id)
                        } label: {
                            Label("Remove from list", systemImage: "trash")
                        }
                    }
                }
                .onAppear {
                    onRowAppear(place)
                    if display.loadMoreTriggerIds.contains(place.place_id.lowercased()) {
                        onLoadMore()
                    }
                }
            }
            // Skeletons only stand in for matches that are still loading, never for tiles already in memory.
            ForEach(0..<max(isLoadingMore ? 2 : 0, filterVM.pendingSkeletonCount(loaded: places)), id: \.self) { _ in
                ListPlaceTileSkeleton(width: tileWidth)
            }
        }
    }
}

// MARK: - Tile

/// Large square photo tile: rounded photo (or colored placeholder), name and a short meta line below.
/// Selected tiles get an accent ring. Tap once to select/center the pin, again to open the place.
struct ListPlaceTileView: View {
    let place: LightweightPlace
    let locationText: String?
    let isSelected: Bool
    let showAddedBy: Bool
    /// Fixed width for the horizontal row; nil fills the grid column.
    let width: CGFloat?
    let onTap: () -> Void

    private let radius: CGFloat = 12
    @ObservedObject private var hoursStore = PlaceHoursStore.shared

    var body: some View {
        // Compute hours state once per render (it was evaluated three times per tile).
        let hoursState = hoursStore.state(for: place.place_id)
        return VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    GeometryReader { geo in
                        ListPlaceThumbnail(place: place, size: geo.size.width, cornerRadius: radius, showsShadow: false)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let state = hoursState {
                        OpenNowPill(isOpen: state.isOpen)
                            .padding(7)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(isSelected ? Color.mesaAccent : Color.gray.opacity(0.15),
                                lineWidth: isSelected ? 3 : 1)
                )
                // Shadow is cast by a plain rounded rect behind the photo (cheap, known shape) instead of by the
                // clipped photo/overlay stack, which forced an offscreen render pass per tile while scrolling.
                .background(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color(.systemBackground))
                        .shadow(color: Color.black.opacity(isSelected ? 0.16 : 0.07), radius: isSelected ? 8 : 5, x: 0, y: 3)
                )
                .scaleEffect(isSelected ? 1.0 : 0.985)

            VStack(alignment: .leading, spacing: 2) {
                Text(LightweightPlace.displayName(place.name))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                // Every line is always laid out (blank when missing) so all tiles in a row
                // are the same height and the grid stays aligned.
                if let state = hoursState {
                    // Glanceable status line: "Open · Closes 10 PM" / "Closed · Opens 9 AM".
                    HStack(spacing: 4) {
                        Text(state.isOpen ? "Open" : "Closed")
                            .fontWeight(.semibold)
                            .foregroundColor(state.isOpen ? .green : .secondary)
                        if let change = PlaceHours.changeText(for: state, timeZone: hoursStore.timeZone(for: place.place_id)) {
                            Text("· \(change)").foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .lineLimit(1)
                } else {
                    Text(" ").font(.caption).lineLimit(1).accessibilityHidden(true)
                }
                Text(meta ?? " ")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 2)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? AccessibilityTraits([.isButton, .isSelected]) : AccessibilityTraits.isButton)
    }

    private var meta: String? {
        if showAddedBy, let addedBy = place.added_by_name, !addedBy.isEmpty {
            return "Added by \(addedBy)"
        }
        return ListPlaceRowView.subtitle(for: place, locationText: locationText)
    }
}

/// Small "Open" (green dot) / "Closed" pill drawn over a tile photo.
struct OpenNowPill: View {
    let isOpen: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOpen ? Color.green : Color.white.opacity(0.7))
                .frame(width: 6, height: 6)
            Text(isOpen ? "Open" : "Closed")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.black.opacity(isOpen ? 0.55 : 0.4)))
        .accessibilityLabel(isOpen ? "Open now" : "Closed")
    }
}

/// Shimmer skeleton shaped like `ListPlaceTileView`.
struct ListPlaceTileSkeleton: View {
    let width: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerView()
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            SkeletonBlock(width: 110, height: 13, cornerRadius: 6)
            SkeletonBlock(width: 80, height: 10, cornerRadius: 5)
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .topLeading)
        .accessibilityHidden(true)
    }
}
