//
//  SavedCityDetailView.swift
//  loc
//
//  One list for a city (or smart group): a horizontally scrolling chip row at the top
//  (All, types, cuisines) filters the places instantly. Nearest first when location is on.
//

import SwiftUI

struct SavedCityDetailView: View {
    @StateObject private var viewModel: SavedCityDetailViewModel
    @State private var selectedPlaceId: String?

    /// Creates the detail screen from plain data; it builds its own ViewModel.
    init(title: String, places: [SavedLibraryPlace], ordering: SavedCityDetailViewModel.Ordering, showsCity: Bool) {
        _viewModel = StateObject(wrappedValue: SavedCityDetailViewModel(title: title, places: places, ordering: ordering, showsCity: showsCity))
    }

    var body: some View {
        VStack(spacing: 0) {
            chipRow
            Divider()
            List {
                ForEach(viewModel.visiblePlaces) { place in
                    SavedPlaceRow(
                        name: place.name,
                        detail: viewModel.subtitle(for: place),
                        systemImage: place.type.systemImage,
                        onTap: { selectedPlaceId = place.id }
                    )
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedPlaceId) { placeId in
            PlaceDetailViewInNavigation(placeId: placeId, minSheetHeight: 250, shouldAnimateMap: false)
        }
        .analyticsScreen("Saved City")
    }

    private var chipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.chips) { chip in
                    SavedFilterChip(title: chip.title, count: chip.count, isSelected: viewModel.selected == chip.kind) {
                        withAnimation(.easeOut(duration: 0.15)) { viewModel.select(chip.kind) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}
