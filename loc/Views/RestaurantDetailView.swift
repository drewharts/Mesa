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
                    .font(.headline)
                    .padding()
            } else {
                // Expanded State Content
                Text(place.name ?? "Unknown")
                    .font(.title)
                    .bold()
                Text(place.formattedAddress ?? "Unknown Address")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}




