//
//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces


struct RestaurantDetailView: View {
    let place: GMSPlace // Accept GMSPlace directly

    var body: some View {
        VStack(spacing: 16) {
            Text(place.name ?? "Unknown") // Access name from GMSPlace
                .font(.title)
                .bold()
            
            Text(place.formattedAddress ?? "Unknown Address") // Access address from GMSPlace
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
        .padding()
    }
}



