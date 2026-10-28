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

    @ObservedObject private var sheetVM = ListMapSheetViewModel.shared

    static let rowTileSize: CGFloat = 150

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var isCollapsed: Bool { sheetVM.detent == .peek }

    private func isSelected(_ place: LightweightPlace) -> Bool {
        guard let focusedPlaceId else { return false }
        return focusedPlaceId.caseInsensitiveCompare(place.place_id) == .orderedSame
    }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if places.isEmpty && !isLoadingInitial {
                    Text("No places in this list")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if isCollapsed {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            content(tileWidth: Self.rowTileSize)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .transition(.opacity)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            content(tileWidth: nil)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: isCollapsed)
            .onAppear { PlaceHoursStore.shared.prefetch(places.map(\.place_id)) }
            .onChange(of: places.count) { _, _ in PlaceHoursStore.shared.prefetch(places.map(\.place_id)) }
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
    private func content(tileWidth: CGFloat?) -> some View {
        if places.isEmpty {
            ForEach(0..<6, id: \.self) { _ in
                ListPlaceTileSkeleton(width: tileWidth)
            }
        } else {
            ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                ListPlaceTileView(
                    place: place,
                    locationText: locationText(place.place_id),
                    isSelected: isSelected(place),
                    showAddedBy: showAddedBy,
                    width: tileWidth,
                    onTap: { onSelect(place) }
                )
                .id(place.place_id)
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
                    if index >= places.count - 3 {
                        onLoadMore()
                    }
                }
            }
            if isLoadingMore {
                ListPlaceTileSkeleton(width: tileWidth)
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
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    GeometryReader { geo in
                        ListPlaceThumbnail(place: place, size: geo.size.width, cornerRadius: radius, showsShadow: false)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    if let state = hoursStore.state(for: place.place_id) {
                        OpenNowPill(isOpen: state.isOpen)
                            .padding(7)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(isSelected ? Color.mesaAccent : Color.gray.opacity(0.15),
                                lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: Color.black.opacity(isSelected ? 0.16 : 0.07), radius: isSelected ? 8 : 5, x: 0, y: 3)
                .scaleEffect(isSelected ? 1.0 : 0.985)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                if let state = hoursStore.state(for: place.place_id) {
                    // Glanceable status line: "Open · Closes 10 PM" / "Closed · Opens 9 AM".
                    HStack(spacing: 4) {
                        Text(state.isOpen ? "Open" : "Closed")
                            .fontWeight(.semibold)
                            .foregroundColor(state.isOpen ? .green : .secondary)
                        if let change = hoursStore.changeText(for: place.place_id) {
                            Text("· \(change)").foregroundColor(.secondary)
                        }
                    }
                    .font(.caption)
                    .lineLimit(1)
                }
                if let meta = meta {
                    Text(meta)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(width: width)
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
        .accessibilityHidden(true)
    }
}
