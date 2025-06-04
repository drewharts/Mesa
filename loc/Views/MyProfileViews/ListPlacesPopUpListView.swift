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

    var body: some View {
        if let _ = profile.userListsPlaces[list.id.uuidString] {
            if !places.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 15) {
                        ForEach(places, id: \ .id) { place in
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
                Text("No places in this list")
                    .foregroundColor(.gray)
                    .padding(.vertical, 30)
            }
        } else {
            Text("Loading places...")
                .foregroundColor(.gray)
                .padding(.vertical, 30)
        }
    }
}
