//
//  LightweightListPopupView.swift
//  loc
//
//  Created by Claude on 1/20/25.
//

import SwiftUI

struct LightweightListPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var dataManager: DataManager
    
    let list: LightweightPlaceList
    let places: [LightweightPlace]
    @Binding var placeColors: [UUID: Color]
    
    @State private var showOnlyUnvisited: Bool = false
    @State private var isLoadingMore: Bool = false
    @State private var hasMorePlaces: Bool = true
    @State private var currentPage: Int = 1
    
    // Same layout as original popup
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Get all places for this list (from profile state)
    var allPlaces: [LightweightPlace] {
        return profile.lightweightPlaceListPlaces[list.list_id] ?? places
    }
    
    // Filtered places based on visited status
    var filteredPlaces: [LightweightPlace] {
        guard showOnlyUnvisited else { return allPlaces }
        
        // Filter out places that the current user has reviewed
        return allPlaces.filter { place in
            !profile.hasReviewedPlace(placeId: place.place_id)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with list name and controls
                VStack(spacing: 12) {
                    // Top bar with close button and share button
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        // Share button (if needed)
                        if let userId = profile.user?.id {
                            // TODO: Implement share functionality for lightweight lists
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // List name and place count
                    VStack(spacing: 4) {
                        Text(list.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        
                        Text("\(list.place_count) place\(list.place_count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.horizontal, 20)
                    
                    // Filter toggle
                    HStack {
                        Button(action: {
                            showOnlyUnvisited.toggle()
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: showOnlyUnvisited ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(showOnlyUnvisited ? .blue : .gray)
                                
                                Text("Show only unvisited")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
                
                // Content
                if !filteredPlaces.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(Array(filteredPlaces.enumerated()), id: \.element.id) { index, place in
                                LightweightPlaceGridCell(
                                    place: place,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                                .onAppear {
                                    // Load more when user scrolls to 3rd-to-last item
                                    if index == allPlaces.count - 3 {
                                        loadMoreIfNeeded()
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        
                        // Loading indicator at bottom
                        if isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding()
                                Spacer()
                            }
                        }
                    }
                } else {
                    VStack(spacing: 8) {
                        Spacer()
                        if showOnlyUnvisited {
                            Text("No unvisited places in this list")
                                .foregroundColor(.gray)
                            Text("All places have been reviewed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("No places in this list")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 30)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Ensure reviewed places are loaded for filtering
            profile.loadMyReviewedPlacesWithPagination()
            
            // Initialize pagination state based on initial places
            hasMorePlaces = places.count >= 6
            currentPage = 1
        }
    }
    
    private func loadMoreIfNeeded() {
        guard !isLoadingMore && hasMorePlaces else { return }
        
        isLoadingMore = true
        let nextPage = currentPage + 1
        
        Task {
            do {
                let morePlaces = try await dataManager.userService.fetchPlacesForPlaceList(
                    listId: list.list_id,
                    page: nextPage,
                    pageSize: 6
                )
                
                await MainActor.run {
                    // Append new places to the profile state
                    if var existingPlaces = profile.lightweightPlaceListPlaces[list.list_id] {
                        existingPlaces.append(contentsOf: morePlaces)
                        profile.lightweightPlaceListPlaces[list.list_id] = existingPlaces
                    } else {
                        profile.lightweightPlaceListPlaces[list.list_id] = morePlaces
                    }
                    
                    currentPage = nextPage
                    hasMorePlaces = morePlaces.count >= 6
                    isLoadingMore = false
                }
                
                print("✅ [LightweightListPopupView] Loaded \(morePlaces.count) more places for list (page \(nextPage))")
            } catch {
                await MainActor.run {
                    isLoadingMore = false
                }
                print("❌ [LightweightListPopupView] Error loading more places: \(error.localizedDescription)")
            }
        }
    }
}

// Note: LightweightPlaceGridCell is defined in MyPlacesListView.swift and used here

// Preview
struct LightweightListPopupView_Previews: PreviewProvider {
    static var previews: some View {
        LightweightListPopupView(
            list: LightweightPlaceList(
                list_id: "test-id",
                name: "Test List",
                is_public: true,
                image: nil,
                created_at: "2025-01-20",
                updated_at: "2025-01-20",
                distance_meters: 100.0,
                place_count: 5
            ),
            places: [
                LightweightPlace(
                    place_id: "place-1",
                    name: "Test Place 1",
                    latest_review_photo: nil
                ),
                LightweightPlace(
                    place_id: "place-2",
                    name: "Test Place 2",
                    latest_review_photo: nil
                )
            ],
            placeColors: .constant([:])
        )
    }
}
