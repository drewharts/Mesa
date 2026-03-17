//
//  TripCompletedView.swift
//  loc
//
//  Success state after trip creation completes
//

import SwiftUI

/// Shows success message with option to view the created trip.
struct TripCompletedView: View {
    let tripId: String
    let onDone: () -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Trip Created!")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Your trip is ready. Start adding places to your itinerary.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onDone()
            } label: {
                Text("Start Planning")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(mesaCharcoal))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
