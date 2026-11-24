//
//  ExploreCityListsView.swift
//  loc
//
//  A city's public lists in a grid, sortable by Popular / Newest / Most places.
//

import SwiftUI

/// Pushed from "Browse by city": sort chips above a two-column grid of list cards.
struct ExploreCityListsView: View {
    @StateObject private var viewModel: ExploreCityListsViewModel
    @EnvironmentObject var userSession: UserSession
    let onListTap: (ExploreList) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Creates the screen for one city.
    init(city: ExploreCity, onListTap: @escaping (ExploreList) -> Void) {
        self._viewModel = StateObject(wrappedValue: ExploreCityListsViewModel(city: city))
        self.onListTap = onListTap
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sortChips
                content
            }
            .padding(.vertical, 8)
        }
        .navigationTitle(viewModel.city.name)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: userSession.currentUserId) {
            await viewModel.load(userId: userSession.currentUserId)
        }
    }

    // MARK: - Subviews

    private var sortChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExploreListSort.allCases) { option in
                    FilterChip(label: option.rawValue, isSelected: viewModel.sort == option) {
                        viewModel.sort = option
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.lists.isEmpty {
            if viewModel.isLoading || !viewModel.hasLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            } else {
                Text("No public lists in \(viewModel.city.name) yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(viewModel.sortedLists) { list in
                    ExploreListCard(list: list) { onListTap(list) }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
