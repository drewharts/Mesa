//
//  ListPlacesPopUpListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

// DUMB Component: Displays list places in a grid layout
// Uses ProfileReviewsViewModel for reviewed place state
struct ListPlacesPopUpListView: View {
    let list: PlaceList

    @ObservedObject var listsVM: ProfileListsViewModel
    @ObservedObject var reviewsVM: ProfileReviewsViewModel

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    // Reduced width to create more space between cards
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35 // Increased spacing from edges
    private let cardHeight: CGFloat = 180 // Slightly reduced height

    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]

    // Precompute places
    var places: [DetailPlace] {
        guard let placeIds = listsVM.userListsPlaces[list.id.uuidString] else { return [] }
        return placeIds.compactMap { detailPlaceViewModel.places[$0] }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Content
            if let _ = listsVM.userListsPlaces[list.id.uuidString] {
                if !places.isEmpty {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(places, id: \.id) { place in
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
                        Text("No places in this list")
                            .foregroundColor(.gray)
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
            // Load reviewed place IDs from database via ViewModel for accurate filtering
            loadReviewedPlaceIdsViaViewModel()
        }
        .onChange(of: places) { _, _ in
            // Reload reviewed IDs when places change via ViewModel
            loadReviewedPlaceIdsViaViewModel()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Delegate to ViewModel to load reviewed place IDs (no business logic here)
    private func loadReviewedPlaceIdsViaViewModel() {
        let placeIds = places.map { $0.id.uuidString }
        Task {
            await reviewsVM.loadVerifiedReviewedPlaceIds(for: placeIds)
        }
    }
}
