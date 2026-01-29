//
//  ListPlacesPopupView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ListPlacesPopupView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    let list: PlaceList
    @State private var showingDeleteConfirmation = false
    @Binding var placeColors: [UUID: Color]
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Reduced width to create more space between cards
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35 // Increased spacing from edges
    private let cardHeight: CGFloat = 180 // Slightly reduced height
    
    var body: some View {
        ListPlacesPopupContent(
            list: list,
            placeColors: $placeColors,
            showingDeleteConfirmation: $showingDeleteConfirmation
        )
        .onAppear {
            if let placeIds = profile.listsViewModel.userListsPlaces[list.id.uuidString] {
                let places = placeIds.compactMap { detailPlaceViewModel.places[$0] }
                for place in places {
                    if placeColors[place.id] == nil {
                        placeColors[place.id] = Color(
                            red: Double.random(in: 0...1),
                            green: Double.random(in: 0...1),
                            blue: Double.random(in: 0...1)
                        )
                    }
                }
            }
        }
        .alert("Delete List", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                profile.removePlaceList(placeList: list)
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this list? This action cannot be undone.")
        }
    }
}
