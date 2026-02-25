//
//  ListsSearchBar.swift
//  loc
//
//  DUMB Component: Unified search bar combining shared filter, search field, and add list menu
//  Single Responsibility: Render the lists search/filter bar UI based on passed-in state
//
//  Layout: [Shared circle btn] [Search capsule w/ TextField] [Plus circle menu]
//

import SwiftUI

struct ListsSearchBar: View {
    // MARK: - Parameters

    @Binding var searchText: String
    var showOnlyShared: Bool
    var hasSharedLists: Bool
    var isFilterEnabled: Bool
    var onToggleFilter: () -> Void
    var onAddList: () -> Void
    var onImportGoogleMapsList: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: 10) {
            if hasSharedLists || !isFilterEnabled {
                sharedButton
            }
            searchCapsule
            plusMenu
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Shared Filter Button

    private var sharedButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggleFilter()
            }
        } label: {
            Group {
                if !isFilterEnabled {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: showOnlyShared ? "person.2.fill" : "person.2")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(showOnlyShared ? .white : .primary)
                }
            }
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(sharedButtonBackground)
            )
        }
        .disabled(!isFilterEnabled)
    }

    private var sharedButtonBackground: Color {
        if !isFilterEnabled {
            return Color(.systemGray5).opacity(0.6)
        }
        return showOnlyShared ? Color.primary : Color(.systemGray5).opacity(0.6)
    }

    // MARK: - Search Capsule

    private var searchCapsule: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))

            TextField("Search lists...", text: $searchText)
                .font(.subheadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(.systemGray5).opacity(0.6))
        )
    }

    // MARK: - Plus Menu

    private var plusMenu: some View {
        Menu {
            Button {
                onAddList()
            } label: {
                Label("New List", systemImage: "plus")
            }
            Button {
                onImportGoogleMapsList()
            } label: {
                Label("Import from Google Maps", systemImage: "map")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color(.systemGray5).opacity(0.6))
                )
        }
    }
}
