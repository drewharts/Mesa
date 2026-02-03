//
//  ProfileListsSection.swift
//  loc
//
//  Shared lists section component for profile views.
//  Used by both MyProfile and ExternalProfile list views.
//
//  Single Responsibility: Display a grid of list cards with loading and empty states.
//

import SwiftUI

/// Configuration for the profile lists section.
struct ProfileListsSectionConfig {
    let isEditable: Bool           // Can create/delete lists
    let showSharedFilter: Bool     // Show shared filter toggle
    let showSearch: Bool           // Show search functionality
    let isMyProfile: Bool          // Affects empty state messaging

    static let myProfile = ProfileListsSectionConfig(
        isEditable: true,
        showSharedFilter: true,
        showSearch: true,
        isMyProfile: true
    )

    static let external = ProfileListsSectionConfig(
        isEditable: false,
        showSharedFilter: false,
        showSearch: false,
        isMyProfile: false
    )
}

/// Shared lists section component for profile views.
struct ProfileListsSection: View {
    let lists: [LightweightPlaceList]
    let placesForList: (String) -> [LightweightPlace]
    let config: ProfileListsSectionConfig
    let isLoading: Bool
    let isLoadingMore: Bool

    // Callbacks
    let onListTap: (LightweightPlaceList, Int) -> Void
    let onListAppear: (LightweightPlaceList) -> Void
    let onCreateList: (() -> Void)?
    let onDeleteList: ((LightweightPlaceList) -> Void)?

    @Binding var placeColors: [UUID: Color]

    // 2-column grid layout
    private let listColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader
            listContent
        }
    }

    // MARK: - Section Header

    private var sectionHeader: some View {
        Text("Lists")
            .font(.headline)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 16)
            .foregroundColor(.primary)
    }

    // MARK: - List Content

    @ViewBuilder
    private var listContent: some View {
        if isLoading {
            loadingView
        } else if lists.isEmpty {
            emptyStateView
        } else {
            listGrid
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading lists...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 32))
                .foregroundColor(.gray.opacity(0.5))
            Text("No lists available")
                .font(.subheadline)
                .foregroundColor(.gray)
            if config.isMyProfile {
                Text("Create a list to organize your favorite places")
                    .font(.caption)
                    .foregroundColor(.gray.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 20)
    }

    // MARK: - List Grid

    private var listGrid: some View {
        LazyVGrid(columns: listColumns, spacing: 16) {
            ForEach(Array(lists.enumerated()), id: \.element.id) { index, list in
                listCard(list: list, index: index)
                    .onAppear {
                        onListAppear(list)
                    }
            }

            // Pagination loading indicator
            if isLoadingMore {
                paginationLoadingView
            }
        }
        .padding(.horizontal, 16)
    }

    private func listCard(list: LightweightPlaceList, index: Int) -> some View {
        let places = placesForList(list.list_id)
        return ProfileListCard(
            list: list,
            places: places,
            placeColors: $placeColors,
            config: config.isMyProfile ? .myProfile : .external,
            onTap: {
                onListTap(list, index)
            }
        )
        .contextMenu {
            if config.isEditable, let onDelete = onDeleteList {
                Button(role: .destructive) {
                    onDelete(list)
                } label: {
                    Label("Delete List", systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Pagination Loading View

    private var paginationLoadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }
}
