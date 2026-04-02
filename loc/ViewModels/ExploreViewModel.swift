//
//  ExploreViewModel.swift
//  loc
//
//  Manages pagination, city filtering, and loading state for the global Explore video feed.
//

import Foundation
import Combine

@MainActor
class ExploreViewModel: ObservableObject {
    @Published var videos: [ExploreVideoItem] = []
    @Published var isLoading: Bool = false
    @Published var hasLoaded: Bool = false
    @Published var isLoadingMore: Bool = false
    @Published var selectedCity: String?
    @Published var availableCities: [String] = []
    @Published var trendingPlaces: [TrendingPlace] = []

    private let postService = SupabasePostService.shared
    private var currentOffset: Int = 0
    private let pageSize: Int = 20
    private(set) var hasMorePages: Bool = true
    private var cancellables = Set<AnyCancellable>()

    /// Initializes and subscribes to place correction notifications for auto-refresh.
    init() {
        NotificationCenter.default.publisher(for: .externalPlaceCorrected)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.loadInitial() }
            }
            .store(in: &cancellables)
    }

    /// Loads the first page of explore videos, replacing any existing data.
    func loadInitial() async {
        guard !isLoading else { return }
        isLoading = true
        currentOffset = 0
        hasMorePages = true

        do {
            let items = try await postService.fetchExploreVideos(limit: pageSize, offset: 0, city: selectedCity)
            videos = items
            currentOffset = items.count
            hasMorePages = items.count == pageSize
        } catch {
            print("❌ [ExploreViewModel] Failed to load explore videos: \(error)")
        }

        hasLoaded = true
        isLoading = false
    }

    /// Loads the next page of explore videos, appending to existing data.
    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true

        do {
            let items = try await postService.fetchExploreVideos(limit: pageSize, offset: currentOffset, city: selectedCity)
            videos.append(contentsOf: items)
            currentOffset += items.count
            hasMorePages = items.count == pageSize
        } catch {
            print("❌ [ExploreViewModel] Failed to load more explore videos: \(error)")
        }

        isLoadingMore = false
    }

    /// Selects a city filter and reloads the feed.
    func selectCity(_ city: String?) {
        selectedCity = city
        Task { await loadInitial() }
    }

    /// Fetches trending places for the horizontal scroll section.
    func loadTrending() async {
        do {
            trendingPlaces = try await postService.fetchTrendingPlaces(limit: 10)
        } catch {
            print("❌ [ExploreViewModel] Failed to load trending: \(error)")
        }
    }

    /// Fetches the list of cities that have explore content.
    func loadCities() async {
        do {
            availableCities = try await postService.fetchExploreCities()
        } catch {
            print("❌ [ExploreViewModel] Failed to load cities: \(error)")
        }
    }
}
