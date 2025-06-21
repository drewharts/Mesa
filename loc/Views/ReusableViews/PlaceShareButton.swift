//
//  PlaceShareButton.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import SwiftUI

struct PlaceShareButton: View {
    let place: DetailPlace
    @EnvironmentObject private var serviceContainer: ServiceContainer
    
    var body: some View {
        Button(action: {
            serviceContainer.placeShareService.sharePlace(place)
        }) {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .foregroundColor(.primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
} 