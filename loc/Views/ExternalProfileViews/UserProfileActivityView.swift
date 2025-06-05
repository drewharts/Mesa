//
//  UserProfileActivityView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserProfileActivityView: View {
    @ObservedObject var UserProfileVM: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Same grid configuration as ListPlacesPopUpListView
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    // Get places that this user has reviewed
    var reviewedPlaces: [DetailPlace] {
        guard let userId = UserProfileVM.selectedUser?.id else { return [] }
        
        // Find all places where this user is in the placeSavers array
        let reviewedPlaceIds = detailPlaceViewModel.placeSavers.compactMap { (placeId, userIds) -> String? in
            return userIds.contains(userId) ? placeId : nil
        }
        
        // Get the actual DetailPlace objects for those IDs
        return reviewedPlaceIds.compactMap { detailPlaceViewModel.places[$0] }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("PLACES REVIEWED")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                        .foregroundStyle(.black)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    if !reviewedPlaces.isEmpty {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(reviewedPlaces, id: \.id) { place in
                                UserReviewedPlaceGridCell(
                                    place: place,
                                    cardWidth: cardWidth,
                                    cardHeight: cardHeight
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    } else {
                        Text("No places reviewed yet")
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 20)
                            .padding(.vertical, 30)
                    }
                }
                
                Spacer()
            }
            .padding(.bottom, 20)
        }
    }
}

// Custom grid cell for reviewed places (similar to ListPlaceGridCell)
struct UserReviewedPlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Button(action: {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            presentationMode.wrappedValue.dismiss()
        }) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .bottom) {
                    if let image = detailPlaceViewModel.placeImages[place.id.uuidString] {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: cardWidth, height: cardHeight)
                            .clipped()
                    } else {
                        Rectangle()
                            .foregroundColor(detailPlaceViewModel.colorForPlace(placeId: place.id.uuidString))
                            .frame(width: cardWidth, height: cardHeight)
                    }
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.1),
                            Color.black.opacity(0.2),
                            Color.black.opacity(1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if let type = detailPlaceViewModel.placeTypes[place.id.uuidString] {
                            Text(type)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        } else if let city = place.city {
                            Text(city)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
        }
    }
} 