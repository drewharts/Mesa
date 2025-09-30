//
//  TikTokNoPlacesFoundView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import FirebaseFirestore

struct TikTokNoPlacesFoundView: View {
    let tikTokUrl: String
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var userComment: String = ""
    @State private var showingCommentDialog = false
    @State private var isSubmitting = false
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Place search functionality
    @State private var searchText: String = ""
    @State private var searchResults: [MesaPlaceSuggestion] = []
    @State private var isSearching = false
    @State private var showingPlaceAssignment = false
    @State private var selectedSuggestion: MesaPlaceSuggestion?
    @State private var showingAssignmentConfirmation = false
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            searchSection
            flaggingSection
            Spacer()
            closeButton
        }
        .padding(.vertical, 30)
        .alert("Help Improve Detection", isPresented: $showingCommentDialog) {
            TextField("Describe the place that should have been detected...", text: $userComment, axis: .vertical)
                .lineLimit(3...6)
            Button("Cancel", role: .cancel) {
                userComment = ""
            }
            Button("Submit Flag") {
                submitFlag()
            }
            .disabled(isSubmitting)
        } message: {
            Text("Help us understand what place should have been detected from this TikTok video.")
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") {
                profile.clearNoPlacesFound()
            }
        } message: {
            Text("Operation completed successfully!")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Assign TikTok to Place", isPresented: $showingAssignmentConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Assign") {
                assignTikTokToPlace()
            }
        } message: {
            if let suggestion = selectedSuggestion {
                Text("Assign this TikTok video to '\(suggestion.name)'?")
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Places Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("We couldn't identify any specific places in this TikTok video")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    private var searchSection: some View {
        VStack(spacing: 16) {
            Text("Search for the place shown in this TikTok")
                .font(.headline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
            
            searchField
            searchResultsView
        }
        .padding(.horizontal, 20)
    }
    
    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search for a place...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onSubmit {
                    performSearch()
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    searchResults = []
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var searchResultsView: some View {
        Group {
            if isSearching {
                ProgressView("Searching...")
                    .padding()
            } else if !searchResults.isEmpty {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(searchResults, id: \.id) { suggestion in
                            PlaceSearchResultRow(suggestion: suggestion) {
                                selectedSuggestion = suggestion
                                showingAssignmentConfirmation = true
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
    
    private var flaggingSection: some View {
        VStack(spacing: 12) {
            Text("Still can't find it?")
                .font(.subheadline)
                .fontWeight(.medium)
            
            Button(action: {
                showingCommentDialog = true
            }) {
                HStack {
                    Image(systemName: "flag")
                        .font(.system(size: 16))
                    Text("Flag as Unable to Identify")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.orange)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
    }
    
    private var closeButton: some View {
        Button("Close") {
            profile.clearNoPlacesFound()
        }
        .font(.headline)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.blue)
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Search Functions
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        
        let placeSearchService = PlaceSearchService()
        placeSearchService.searchPlaces(
            query: searchText,
            onResultsUpdated: { suggestions in
                DispatchQueue.main.async {
                    searchResults = suggestions
                    isSearching = false
                }
            },
            onError: { error in
                DispatchQueue.main.async {
                    isSearching = false
                    errorMessage = "Search failed: \(error)"
                    showingErrorAlert = true
                }
            }
        )
    }
    
    private func assignTikTokToPlace() {
        guard let suggestion = selectedSuggestion,
              let userId = userSession.currentUserId else {
            errorMessage = "Unable to assign TikTok to place"
            showingErrorAlert = true
            return
        }
        
        isSubmitting = true
        
        // Create a DetailPlace from the suggestion
        let detailPlace = createDetailPlaceFromSuggestion(suggestion)
        
        // Create external place entry with TikTok video
        let externalTikTokVideo = createExternalTikTokVideoFromUrl()
        let externalPlace = ExternalPlace(
            id: detailPlace.id.uuidString,
            addedAt: Date(),
            address: detailPlace.address ?? "",
            coordinates: ExternalPlaceCoordinates(
                latitude: detailPlace.coordinate?.latitude ?? 0,
                longitude: detailPlace.coordinate?.longitude ?? 0
            ),
            name: detailPlace.name,
            placeId: detailPlace.id.uuidString,
            source: "user_assigned",
            tiktokVideos: [externalTikTokVideo]
        )
        
        // Save to user's external places
        profile.saveExternalPlace(externalPlace: externalPlace) { success, error in
            DispatchQueue.main.async {
                isSubmitting = false
                if success {
                    // Refresh TikTok places list
                    profile.refreshTikTokPlacesAfterImport()
                    showingSuccessAlert = true
                } else {
                    errorMessage = "Failed to assign TikTok: \(error?.localizedDescription ?? "Unknown error")"
                    showingErrorAlert = true
                }
            }
        }
    }
    
    private func createDetailPlaceFromSuggestion(_ suggestion: MesaPlaceSuggestion) -> DetailPlace {
        var detailPlace = DetailPlace()
        detailPlace.id = UUID(uuidString: suggestion.id) ?? UUID()
        detailPlace.name = suggestion.name
        detailPlace.address = suggestion.address
        detailPlace.coordinate = GeoPoint(
            latitude: suggestion.coordinate.latitude,
            longitude: suggestion.coordinate.longitude
        )
        detailPlace.createdAt = ISO8601DateFormatter().string(from: Date())
        return detailPlace
    }
    
    private func createExternalTikTokVideoFromUrl() -> ExternalTikTokVideo {
        // Extract basic info from the TikTok URL
        let videoID = UUID().uuidString // Generate a temporary ID
        let author = ExternalTikTokAuthor(
            displayName: "Unknown",
            username: ""
        )
        
        return ExternalTikTokVideo(
            author: author,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            embedHtml: "",
            hashtags: [],
            thumbnailUrl: "",
            url: tikTokUrl,
            videoId: videoID
        )
    }
    
    private func submitFlag() {
        guard let userId = userSession.currentUserId else {
            errorMessage = "You must be logged in to submit flags"
            showingErrorAlert = true
            return
        }
        
        isSubmitting = true
        
        // Create a temporary place ID for this flag since no place was found
        let tempPlaceId = "no_place_found_\(UUID().uuidString)"
        
        profile.flagTikTokPlace(for: tempPlaceId, flagType: .unableToIdentify, tikTokUrl: tikTokUrl, userComment: userComment)
        
        // Simulate delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSubmitting = false
            userComment = ""
            showingSuccessAlert = true
        }
    }
}

// MARK: - PlaceSearchResultRow Component
struct PlaceSearchResultRow: View {
    let suggestion: MesaPlaceSuggestion
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Place image placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
                
                // Place info
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = suggestion.address {
                        Text(address)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Text(suggestion.source.capitalized)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}