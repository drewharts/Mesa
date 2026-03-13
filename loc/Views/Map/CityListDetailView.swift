//
//  CityListDetailView.swift
//  loc
//
//  Grid view showing all places in a city list, pushed within the city detail sheet.
//

import SwiftUI

/// Detail view for a single list within the city detail sheet navigation stack.
struct CityListDetailView: View {
    let listId: String
    let listName: String
    let creatorId: String
    let creatorName: String?
    let creatorPhotoUrl: String?
    let onPlaceTap: (String) -> Void
    let onCreatorTap: (String) -> Void
    @StateObject private var viewModel: CityListDetailViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    init(
        listId: String,
        listName: String,
        creatorId: String,
        creatorName: String? = nil,
        creatorPhotoUrl: String? = nil,
        onPlaceTap: @escaping (String) -> Void,
        onCreatorTap: @escaping (String) -> Void
    ) {
        self.listId = listId
        self.listName = listName
        self.creatorId = creatorId
        self.creatorName = creatorName
        self.creatorPhotoUrl = creatorPhotoUrl
        self.onPlaceTap = onPlaceTap
        self.onCreatorTap = onCreatorTap
        self._viewModel = StateObject(wrappedValue: CityListDetailViewModel(listId: listId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.places.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.places.isEmpty {
                emptyState
            } else {
                placesContent
            }
        }
        .navigationTitle(listName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPlaces()
        }
    }

    // MARK: - Places Content

    /// Creator header, filter chips, and places grid.
    private var placesContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                creatorHeader
                typeFilterChips
                placesGrid
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Creator Header

    /// Tappable row showing the list creator's photo, name, and chevron.
    private var creatorHeader: some View {
        Button {
            onCreatorTap(creatorId)
        } label: {
            HStack(spacing: 10) {
                creatorPhoto

                VStack(alignment: .leading, spacing: 2) {
                    Text("Created by")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(creatorName ?? "Unknown")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
    }

    /// Creator's profile photo or initials fallback.
    @ViewBuilder
    private var creatorPhoto: some View {
        if let photoUrl = creatorPhotoUrl, let url = URL(string: photoUrl) {
            CachedAsyncImage(url: url, targetSize: CGSize(width: 36, height: 36)) {
                creatorInitialsCircle
            }
            .aspectRatio(contentMode: .fill)
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        } else {
            creatorInitialsCircle
        }
    }

    /// Fallback circle with creator's initial.
    private var creatorInitialsCircle: some View {
        Circle()
            .fill(Color(.tertiarySystemFill))
            .frame(width: 36, height: 36)
            .overlay(
                Text(String(creatorName?.prefix(1) ?? "").uppercased())
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            )
    }

    // MARK: - Type Filter Chips

    /// Horizontal scroll of type filter pills.
    @ViewBuilder
    private var typeFilterChips: some View {
        if viewModel.availableTypes.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(label: "All", isSelected: viewModel.selectedType == nil) {
                        viewModel.selectedType = nil
                    }

                    ForEach(viewModel.availableTypes, id: \.self) { type in
                        filterChip(
                            label: viewModel.displayName(for: type),
                            isSelected: viewModel.selectedType == type
                        ) {
                            viewModel.toggleTypeFilter(type)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    /// Individual filter chip button.
    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.tertiarySystemFill))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Places Grid

    /// Two-column grid of place cards.
    private var placesGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.filteredPlaces) { place in
                PopupPlaceCard(
                    place: place,
                    preferExternalThumbnail: false,
                    onNavigate: { placeId in
                        onPlaceTap(placeId)
                    }
                )
                .onAppear {
                    Task {
                        await viewModel.loadMoreIfNeeded(currentPlace: place)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Empty State

    /// Shown when the list has no places.
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No places in this list")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
