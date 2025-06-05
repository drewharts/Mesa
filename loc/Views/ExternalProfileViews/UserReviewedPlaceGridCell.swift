//
//  UserReviewedPlaceGridCell.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI

struct UserReviewedPlaceGridCell: View {
    let place: DetailPlace
    let cardWidth: CGFloat
    let cardHeight: CGFloat

    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        Button(action: {
            selectedPlaceVM.selectedPlace = place
            selectedPlaceVM.isDetailSheetPresented = true
            
            // Dismiss the user profile sheet by setting the view model property
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                userProfileViewModel.isUserDetailPresented = false
            }
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