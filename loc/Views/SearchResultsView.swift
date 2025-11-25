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
            .frame(height: isSearching ? 100 : CGFloat((userResults.count + placeResults.count) * 120 + (showNoPlaceFound ? 120 : 0)))
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
                        VStack(alignment: .center) {
                            Text(prediction.name)
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity, alignment: .center)

                            if let secondaryText = prediction.address {
                                Text(secondaryText)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
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
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.horizontal, 20)
    }
}

/// DUMB Component: Displays user search results
struct UserResultsView: View {
    let userResults: [ProfileData]
    let userPhotos: [String: UIImage]  // Profile photos passed as data
    let onSelectUser: (ProfileData) -> Void

    var body: some View {
        if !userResults.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Text("Users")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                
                ForEach(userResults) { user in
                    Button(action: { onSelectUser(user) }) {
                        HStack {
                            profilePhotoView(for: user)
                            
                            VStack(alignment: .leading) {
                                Text(user.fullName)
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                    .padding(.horizontal, 20)
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
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
        }
    }
}
