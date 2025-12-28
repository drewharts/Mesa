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
    
    @State private var isUsersCollapsed: Bool = false

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
            .frame(height: calculateFrameHeight())
        }
    }
    
    private func calculateFrameHeight() -> CGFloat {
        if isSearching {
            return 100
        }
        
        let userHeight: CGFloat = userResults.isEmpty ? 0 : (isUsersCollapsed ? 40 : CGFloat(userResults.count * 80 + 40))
        let placeHeight: CGFloat = CGFloat(placeResults.count * 120)
        let noPlaceHeight: CGFloat = showNoPlaceFound ? 120 : 0
        
        return userHeight + placeHeight + noPlaceHeight + 20
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
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Image(systemName: isCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.gray.opacity(0.8))
                        
                        Spacer()
                    }
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
        .fixedSize(horizontal: false, vertical: true)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Recent")
                .font(.headline)
                .foregroundColor(.gray)
            
            Spacer()
            
            Button(action: onClearAll) {
                Text("Clear")
                    .font(.subheadline)
                    .foregroundColor(.gray)
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
