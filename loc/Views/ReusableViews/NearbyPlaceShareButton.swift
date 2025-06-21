//
//  NearbyPlaceShareButton.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import SwiftUI

struct NearbyPlaceShareButton: View {
    let nearbyPlace: NearbyPlaceFeature
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.sharePlace(nearbyPlace)
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 