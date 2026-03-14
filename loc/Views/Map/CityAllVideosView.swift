//
//  CityAllVideosView.swift
//  loc
//
//  Vertical grid view showing all TikTok videos for a city with pagination.
//

import SwiftUI

/// Full-screen vertical grid of all city TikTok videos, navigated from "See All" in city detail.
struct CityAllVideosView: View {
    @ObservedObject var viewModel: CityDetailViewModel
    let onVideoTap: (CityTikTok) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.tiktoks) { tiktok in
                    CityTikTokTile(tiktok: tiktok, onTap: { onVideoTap(tiktok) })
                        .frame(maxWidth: .infinity)
                        .onAppear { loadMoreIfNeeded(tiktok: tiktok) }
                }
            }
            .padding(.horizontal, 16)

            if viewModel.isLoadingMoreTiktoks {
                ProgressView()
                    .padding(.vertical, 16)
            }
        }
        .navigationTitle("Videos")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Triggers pagination when the user scrolls near the last item.
    private func loadMoreIfNeeded(tiktok: CityTikTok) {
        guard tiktok.id == viewModel.tiktoks.last?.id else { return }
        Task { await viewModel.loadMoreTiktoks() }
    }
}
