//
//  SearchResultsView.swift
//  loc
//
//  Refactored to be a pure DUMB component
//  Single Responsibility: Display search results with no business logic
//

import SwiftUI

/// DUMB Component: Displays search results (places and users)
/// Receives data and callbacks only - no ViewModel dependencies
struct SearchResultsView: View {
    let placeResults: [MesaPlaceSuggestion]
    let userResults: [ProfileData]
    let userPhotos: [String: UIImage]  // Profile photos passed as data
    let showNoPlaceFound: Bool
    let searchText: String
    let isSearching: Bool
    let onSelectPlace: (MesaPlaceSuggestion) -> Void
    let onSelectUser: (ProfileData) -> Void

    // Keyword search results from local database
    let keywordResults: [DetailPlace]
    let matchedKeyword: String?
    let hasMoreKeywordResults: Bool
    let isLoadingMoreKeywords: Bool
    let onSelectKeywordPlace: (DetailPlace) -> Void
    let onLoadMoreKeywords: () -> Void
    let onViewAllKeywords: () -> Void

    // AI suggestions
    let aiSuggestions: [DetailPlace]
    let isAILoading: Bool
    let aiError: String?
    let onSelectAIPlace: (DetailPlace) -> Void

    @State private var isUsersCollapsed: Bool = false
    @State private var isKeywordCollapsed: Bool = false
    @State private var isAICollapsed: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    if isSearching {
                        loadingView
                    } else {
                        UserResultsView(
                            userResults: userResults,
                            userPhotos: userPhotos,
                            isCollapsed: $isUsersCollapsed,
                            onSelectUser: onSelectUser
                        )
                        AISuggestionsSection(
                            suggestions: aiSuggestions,
                            isLoading: isAILoading,
                            error: aiError,
                            isCollapsed: $isAICollapsed,
                            onSelectPlace: onSelectAIPlace
                        )
                        KeywordResultsView(
                            keywordResults: keywordResults,
                            matchedKeyword: matchedKeyword,
                            isCollapsed: $isKeywordCollapsed,
                            hasMoreResults: hasMoreKeywordResults,
                            isLoadingMore: isLoadingMoreKeywords,
                            onSelectPlace: onSelectKeywordPlace,
                            onLoadMore: onLoadMoreKeywords,
                            onViewAll: onViewAllKeywords
                        )
                        PlaceResultsView(
                            placeResults: placeResults,
                            showNoPlaceFound: showNoPlaceFound,
                            searchText: searchText,
                            onSelectPlace: onSelectPlace
                        )
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .frame(maxHeight: geometry.size.height)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

/// DUMB Component: Displays keyword-matched place results from local database
/// Shows places that match keywords like "burger", "coffee", etc.
struct KeywordResultsView: View {
    let keywordResults: [DetailPlace]
    let matchedKeyword: String?
    @Binding var isCollapsed: Bool
    let hasMoreResults: Bool
    let isLoadingMore: Bool
    let onSelectPlace: (DetailPlace) -> Void
    let onLoadMore: () -> Void
    let onViewAll: () -> Void

    var body: some View {
        if !keywordResults.isEmpty, let keyword = matchedKeyword {
            VStack(alignment: .leading, spacing: 0) {
                // Header with collapse toggle and View All button
                HStack(spacing: 6) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCollapsed.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("\(keyword.capitalized) nearby")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    Button(action: onViewAll) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if !isCollapsed {
                    Divider()
                        .padding(.leading, 20)

                    ForEach(Array(keywordResults.enumerated()), id: \.element.id) { index, place in
                        Button(action: { onSelectPlace(place) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange.opacity(0.8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if let address = place.address, !address.isEmpty {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if index < keywordResults.count - 1 || hasMoreResults {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }

                    if hasMoreResults {
                        Button(action: onLoadMore) {
                            HStack {
                                if isLoadingMore {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Load More")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .disabled(isLoadingMore)
                    }
                }
            }
        }
    }
}

/// DUMB Component: Displays place search results
struct PlaceResultsView: View {
    let placeResults: [MesaPlaceSuggestion]
    let showNoPlaceFound: Bool
    let searchText: String
    let onSelectPlace: (MesaPlaceSuggestion) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !placeResults.isEmpty {
                Text("Places")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                Divider()
                    .padding(.leading, 20)

                ForEach(Array(placeResults.enumerated()), id: \.element.id) { index, prediction in
                    Button(action: { onSelectPlace(prediction) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red.opacity(0.8))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(prediction.name)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)

                                if let address = prediction.address, !address.isEmpty {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())

                    if index < placeResults.count - 1 {
                        Divider()
                            .padding(.leading, 56)
                    }
                }
            } else if showNoPlaceFound {
                Text("Places")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)

                noPlacesFoundView
            }
        }
    }

    private var noPlacesFoundView: some View {
        VStack(spacing: 12) {
            Image(systemName: "location.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.6))

            VStack(spacing: 4) {
                Text("No place found")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)

                Text("We couldn't find '\(searchText)' in our database")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }
}

/// DUMB Component: Displays user search results with collapsible functionality
struct UserResultsView: View {
    let userResults: [ProfileData]
    let userPhotos: [String: UIImage]  // Profile photos passed as data
    @Binding var isCollapsed: Bool
    let onSelectUser: (ProfileData) -> Void

    var body: some View {
        if !userResults.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.toggle()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Users")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())

                if !isCollapsed {
                    Divider()
                        .padding(.leading, 20)

                    ForEach(Array(userResults.enumerated()), id: \.element.id) { index, user in
                        Button(action: { onSelectUser(user) }) {
                            HStack(spacing: 12) {
                                profilePhotoView(for: user)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.fullName)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        if index < userResults.count - 1 {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func profilePhotoView(for user: ProfileData) -> some View {
        if let profilePhoto = userPhotos[user.id] {
            Image(uiImage: profilePhoto)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Recent Selections View

/// DUMB Component: Displays recently selected places & users
/// Single Responsibility: Render recent selections with tap/clear actions
/// Receives data and callbacks only - no ViewModel dependencies
struct RecentSearchesView: View {
    let selections: [RecentSelection]
    let userPhotos: [String: UIImage]
    let onSelectPlace: (String) -> Void   // Place ID
    let onSelectUser: (String) -> Void    // User ID
    let onClearAll: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                Divider()
                    .padding(.leading, 20)
                selectionsList
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Recent")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            Spacer()

            Button(action: onClearAll) {
                Text("Clear")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    // MARK: - Selections List

    private var selectionsList: some View {
        ForEach(Array(selections.enumerated()), id: \.element.id) { index, selection in
            Button(action: { handleSelection(selection) }) {
                HStack(spacing: 12) {
                    selectionIcon(for: selection)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.displayName)
                            .font(.body)
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        if let subtitle = selection.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if index < selections.count - 1 {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func selectionIcon(for selection: RecentSelection) -> some View {
        switch selection {
        case .place:
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundColor(.red.opacity(0.8))
        case .user(let id, _, let photoURLString):
            if let photo = userPhotos[id] {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
            } else if let urlString = photoURLString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    case .failure, .empty:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    @unknown default:
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    }
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.gray)
            }
        }
    }

    private func handleSelection(_ selection: RecentSelection) {
        switch selection {
        case .place(let id, _, _):
            onSelectPlace(id)
        case .user(let id, _, _):
            onSelectUser(id)
        }
    }
}
