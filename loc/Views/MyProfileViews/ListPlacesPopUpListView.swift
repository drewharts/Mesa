//
//  ListPlacesPopUpListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ListPlacesPopUpListView: View {
    let list: PlaceList

    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var showOnlyUnvisited: Bool = false
    
    // MARK: - Reviewed Places State (for accurate unvisited filtering)
    @State private var reviewedPlaceIds: Set<String> = []
    @State private var isLoadingReviewedIds: Bool = false

    // Reduced width to create more space between cards
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35 // Increased spacing from edges
    private let cardHeight: CGFloat = 180 // Slightly reduced height
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Precompute places
    var places: [DetailPlace] {
        guard let placeIds = profile.userListsPlaces[list.id.uuidString] else { return [] }
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }
    
    // Filtered places based on visited status (uses database-verified reviewed IDs)
    var filteredPlaces: [DetailPlace] {
        guard showOnlyUnvisited else { return places }
        
        // Filter out places that the current user has reviewed (checked against database)
        return places.filter { place in
            !reviewedPlaceIds.contains(place.id.uuidString)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filter button in top left corner
            HStack {
                Button(action: {
                    showOnlyUnvisited.toggle()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: showOnlyUnvisited ? "eye.slash.fill" : "list.bullet")
                            .foregroundColor(showOnlyUnvisited ? .white : .secondary)
                            .font(.caption)
                        Text(showOnlyUnvisited ? "Unvisited" : "All")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(showOnlyUnvisited ? .white : .secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(showOnlyUnvisited ? Color.blue : Color(.systemGray5))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
            
            // Content
            if let _ = profile.userListsPlaces[list.id.uuidString] {
                if !filteredPlaces.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(filteredPlaces, id: \.id) { place in
                                ListPlaceGridCell(
                                    place: place,
                                    list: list,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
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
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.vertical, 30)
            }
        }
        .onAppear {
            // Load reviewed place IDs from database for accurate filtering
            loadReviewedPlaceIds()
        }
        .onChange(of: places) { _, _ in
            // Reload reviewed IDs when places change
            loadReviewedPlaceIds()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Load reviewed place IDs from database for accurate unvisited filtering
    private func loadReviewedPlaceIds() {
        guard let userId = profile.user?.id else { return }
        
        let placeIds = places.map { $0.id.uuidString }
        guard !placeIds.isEmpty else { return }
        
        // Don't reload if already loading
        guard !isLoadingReviewedIds else { return }
        
        isLoadingReviewedIds = true
        
        Task {
            do {
                let ids = try await SupabaseReviewService.shared.getReviewedPlaceIds(
                    userId: userId,
                    placeIds: placeIds
                )
                await MainActor.run {
                    self.reviewedPlaceIds = ids
                    self.isLoadingReviewedIds = false
                }
            } catch {
                print("❌ [ListPlacesPopUpListView] Error loading reviewed place IDs: \(error)")
                await MainActor.run {
                    self.isLoadingReviewedIds = false
                }
            }
        }
    }
}
