//
//  ExploreViewModel.swift
//  loc
//
//  Manages pagination and loading state for the global Explore video feed.
//

import Foundation
import Combine

@MainActor
class ExploreViewModel: ObservableObject {
    @Published var videos: [ExploreVideoItem] = []
    @Published var isLoading: Bool = false
    @Published var isLoadingMore: Bool = false

    private let postService = SupabasePostService.shared
    private var currentOffset: Int = 0
    private let pageSize: Int = 20
    private(set) var hasMorePages: Bool = true
    private var cancellables = Set<AnyCancellable>()

    /// Sets up subscription to refresh after place corrections.
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
            let items = try await postService.fetchExploreVideos(limit: pageSize, offset: 0)
            videos = items
            currentOffset = items.count
            hasMorePages = items.count == pageSize
        } catch {
            print("❌ [ExploreViewModel] Failed to load explore videos: \(error)")
        }

        isLoading = false
    }

    /// Loads the next page of explore videos, appending to existing data.
    func loadMore() async {
        guard !isLoadingMore, hasMorePages else { return }
        isLoadingMore = true

        do {
            let items = try await postService.fetchExploreVideos(limit: pageSize, offset: currentOffset)
            videos.append(contentsOf: items)
            currentOffset += items.count
            hasMorePages = items.count == pageSize
        } catch {
            print("❌ [ExploreViewModel] Failed to load more explore videos: \(error)")
        }

        isLoadingMore = false
    }
}
