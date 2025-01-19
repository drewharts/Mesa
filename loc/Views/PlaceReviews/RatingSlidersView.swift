//
//  RatingSlidersView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct RatingSlidersView: View {
    @Binding var foodRating: Double
    @Binding var serviceRating: Double
    @Binding var ambienceRating: Double

    var body: some View {
        VStack(spacing: 8) {
            SliderRow(title: "Food", value: $foodRating)
                .accessibilityIdentifier("foodSlider")
            SliderRow(title: "Service", value: $serviceRating)
                .accessibilityIdentifier("serviceSlider")
            SliderRow(title: "Ambience", value: $ambienceRating)
                .accessibilityIdentifier("ambienceSlider")
            
            Divider()
                .padding(.top, 15)
                .padding(.bottom, 10)
                .padding(.horizontal, -20)
        }
    }
}