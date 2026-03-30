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
        ScrollView {
            VStack(spacing: 0) {
                citySearchSection
                if viewModel.isLoading && viewModel.videos.isEmpty {
                    loadingView
                } else if viewModel.videos.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    videoGrid
                }
            }
        }
        .refreshable {
            await viewModel.loadInitial()
        }
        .task {
            if viewModel.availableCities.isEmpty {
                await viewModel.loadCities()
            }
            if viewModel.videos.isEmpty {
                await viewModel.loadInitial()
            }
        }
    }

    // MARK: - City Search

    private var citySearchSection: some View {
        VStack(spacing: 8) {
            citySearchBar
            if let selected = viewModel.selectedCity {
                activeFilterChip(selected)
            }
            if showCitySuggestions && !filteredCities.isEmpty {
                citySuggestionsList
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

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
                            .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))
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

    /// Chip showing the active city filter with dismiss button.
    @ViewBuilder
    private var activeFilterChip: (String) -> some View {
        { city in
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                    Text(city)
                        .font(.caption)
                        .fontWeight(.medium)
                    Button {
                        viewModel.selectCity(nil)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(red: 0.8, green: 0.4, blue: 0.1))
                .clipShape(Capsule())

                Spacer()
            }
        }
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
