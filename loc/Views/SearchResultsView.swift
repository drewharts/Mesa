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

    @State private var isUsersCollapsed: Bool = false
    @State private var isKeywordCollapsed: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 10) {
                    if isSearching {
                        loadingView
                    } else {
                        UserResultsView(
                            userResults: userResults,
                            userPhotos: userPhotos,
                            isCollapsed: $isUsersCollapsed,
                            onSelectUser: onSelectUser
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
            VStack(alignment: .leading, spacing: 5) {
                // Header with collapse toggle and View All button
                HStack(spacing: 6) {
                    // Collapse/expand button
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemBackground))
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    // View All button - shows full list popup with map annotations
                    Button(action: onViewAll) {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(Color(.systemBackground))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .contentShape(Rectangle())

                // Keyword results - only show when not collapsed
                if !isCollapsed {
                    ForEach(keywordResults, id: \.id) { place in
                        Button(action: { onSelectPlace(place) }) {
                            HStack(spacing: 12) {
                                Image(systemName: "fork.knife.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.orange.opacity(0.8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .font(.body)
                                        .foregroundColor(.black)
                                        .lineLimit(1)

                                    if let address = place.address, !address.isEmpty {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
                    }

                    // Load More button
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
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
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
        VStack(alignment: .leading, spacing: 5) {
            if !placeResults.isEmpty {
                Text("Places")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
                ForEach(placeResults, id: \.id) { prediction in
                    Button(action: { onSelectPlace(prediction) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red.opacity(0.8))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(prediction.name)
                                    .font(.body)
                                    .foregroundColor(.black)
                                    .lineLimit(1)
                                
                                if let address = prediction.address, !address.isEmpty {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 20)
                }
            } else if showNoPlaceFound {
                Text("Places")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                
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
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
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
            VStack(alignment: .leading, spacing: 5) {
                // Tappable header to collapse/expand
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
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                
                // User results - only show when not collapsed
                if !isCollapsed {
                    ForEach(userResults) { user in
                        Button(action: { onSelectUser(user) }) {
                            HStack(spacing: 12) {
                                profilePhotoView(for: user)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.fullName)
                                        .font(.body)
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(10)
                            .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 20)
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
            VStack(alignment: .leading, spacing: 8) {
                headerView
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
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemBackground))
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)

            Spacer()

            Button(action: onClearAll) {
                Text("Clear")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }
    
    // MARK: - Selections List
    
    private var selectionsList: some View {
        ForEach(selections) { selection in
            Button(action: { handleSelection(selection) }) {
                HStack(spacing: 12) {
                    selectionIcon(for: selection)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection.displayName)
                            .font(.body)
                            .foregroundColor(.black)
                            .lineLimit(1)
                        
                        if let subtitle = selection.subtitle, !subtitle.isEmpty {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 20)
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
            // Try cached photo first, then fall back to AsyncImage
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
