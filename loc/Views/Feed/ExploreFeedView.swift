//
//  ExploreFeedView.swift
//  loc
//
//  2-column grid of globally imported TikTok/Instagram content for discovery.
//  Includes city filter pills for filtering by location.
//

import SwiftUI

struct ExploreFeedView: View {
    @ObservedObject var viewModel: ExploreViewModel
    let onPlaceTap: (String) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cityFilterPills
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

    // MARK: - City Filter

    private var cityFilterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ExploreCityPill(title: "All", isSelected: viewModel.selectedCity == nil) {
                    viewModel.selectCity(nil)
                }
                ForEach(viewModel.availableCities, id: \.self) { city in
                    ExploreCityPill(title: city, isSelected: viewModel.selectedCity == city) {
                        viewModel.selectCity(city)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
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
