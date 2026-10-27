//
//  ListPlacesScrollView.swift
//  loc
//
//  Scrollable column of place rows shared by the own-list and external-list sheets.
//  Handles shimmer skeletons, empty state, pagination trigger, and scrolling a row into view
//  when its map pin is tapped. DUMB component: no view models, all actions are closures.
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

    private func isSelected(_ place: LightweightPlace) -> Bool {
        guard let focusedPlaceId else { return false }
        return focusedPlaceId.caseInsensitiveCompare(place.place_id) == .orderedSame
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if places.isEmpty && isLoadingInitial {
                        ForEach(0..<6, id: \.self) { _ in
                            ListPlaceRowSkeleton()
                        }
                    } else if places.isEmpty {
                        Text("No places in this list")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        ForEach(Array(places.enumerated()), id: \.element.id) { index, place in
                            ListPlaceRowView(
                                place: place,
                                locationText: locationText(place.place_id),
                                isSelected: isSelected(place),
                                showAddedBy: showAddedBy,
                                onTap: { onSelect(place) },
                                onOpenDetail: { onOpenDetail(place) }
                            )
                            .contextMenu {
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
                                // Load more when the user nears the end of the loaded rows.
                                if index >= places.count - 3 {
                                    onLoadMore()
                                }
                            }
                        }

                        if isLoadingMore {
                            ListPlaceRowSkeleton()
                            ListPlaceRowSkeleton()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 32)
            }
            .onChange(of: scrollRequest) { _, request in
                guard let request else { return }
                // Wait for a peek -> half sheet animation to settle before scrolling.
                Task {
                    try? await Task.sleep(nanoseconds: 250_000_000)
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(request.placeId, anchor: .center)
                    }
                }
            }
        }
    }
}
