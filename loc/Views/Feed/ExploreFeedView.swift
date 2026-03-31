//
//  ExploreFeedView.swift
//  loc
//
//  2-column grid of globally imported TikTok/Instagram content for discovery.
//  Includes city search bar for filtering by location.
//

import SwiftUI

struct ExploreFeedView: View {
    @ObservedObject var viewModel: ExploreViewModel
    let onPlaceTap: (String) -> Void

    @State private var citySearchText: String = ""
    @State private var showCitySuggestions: Bool = false
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 0) {
            citySearchSection

            if !viewModel.trendingPlaces.isEmpty {
                trendingSection
            }

            ScrollView {
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    loadingView
                } else if viewModel.hasLoaded && viewModel.videos.isEmpty {
                    emptyState
                } else {
                    videoGrid
                }
            }
            .refreshable {
                await viewModel.loadInitial()
            }
        }
        .task {
            async let cities: () = viewModel.availableCities.isEmpty ? viewModel.loadCities() : ()
            async let videos: () = viewModel.videos.isEmpty ? viewModel.loadInitial() : ()
            async let trending: () = viewModel.loadTrending()
            _ = await (cities, videos, trending)
        }
    }

    // MARK: - City Search

    /// City search bar, active filter chip, and suggestions dropdown.
    private var citySearchSection: some View {
        VStack(spacing: 8) {
            citySearchBar
            if let selected = viewModel.selectedCity {
                ExploreCityChip(city: selected, onClear: { viewModel.selectCity(nil) })
            }
            if showCitySuggestions && !filteredCities.isEmpty {
                citySuggestionsList
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    /// Text field with magnifying glass icon for filtering by city name.
    private var citySearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundColor(.secondary)
            TextField("Filter by city...", text: $citySearchText)
                .font(.subheadline)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .onChange(of: citySearchText) { _, newValue in
                    showCitySuggestions = !newValue.isEmpty
                }
            if !citySearchText.isEmpty {
                Button {
                    citySearchText = ""
                    showCitySuggestions = false
                    isSearchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }

    /// Cities matching the current search text.
    private var filteredCities: [String] {
        let query = citySearchText.lowercased()
        return viewModel.availableCities.filter { $0.lowercased().contains(query) }
    }

    /// Dropdown list of cities matching the search text.
    private var citySuggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(filteredCities.prefix(6), id: \.self) { city in
                Button {
                    viewModel.selectCity(city)
                    citySearchText = ""
                    showCitySuggestions = false
                    isSearchFocused = false
                } label: {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.mesaAccent)
                        Text(city)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                if city != filteredCities.prefix(6).last {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    /// Horizontal scroll of trending (most crowned) places.
    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trending")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.trendingPlaces) { place in
                        TrendingPlaceCard(place: place) {
                            onPlaceTap(place.placeId)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Video Grid

    private var videoGrid: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(viewModel.videos) { video in
                ExploreFeedTile(video: video) {
                    onPlaceTap(video.placeId)
                }
                .onAppear {
                    loadMoreIfNeeded(video)
                }
            }
        }
        .padding(.horizontal)
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("No videos in this city yet")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Helpers

    /// Triggers pagination when the last few items appear.
    private var loadMoreIfNeeded: (ExploreVideoItem) -> Void {
        { video in
            guard let index = viewModel.videos.firstIndex(where: { $0.id == video.id }),
                  index >= viewModel.videos.count - 4 else { return }
            Task { await viewModel.loadMore() }
        }
    }
}
