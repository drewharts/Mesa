//
//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces

struct RestaurantDetailView: View {
    let place: GMSPlace
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat

    var body: some View {
        VStack(spacing: 16) {
            if sheetHeight == minSheetHeight {
                // Collapsed State Content
                Text(place.name ?? "Unknown")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .padding()
            } else {
                // Expanded State Content
                Text(place.name ?? "Unknown")
                    .font(.title)
                    .foregroundStyle(.blue)
                    .bold()
                Text(place.formattedAddress ?? "Unknown Address")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .foregroundStyle(.secondary)
                if let openingHours = place.currentOpeningHours?.weekdayText {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Opening Hours:")
                            .font(.headline)
                            .foregroundColor(.black)
                        ForEach(openingHours, id: \.self) { hour in
                            Text(hour)
                                .font(.subheadline)
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.top, 8)
                } else {
                    Text("Opening hours not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}




