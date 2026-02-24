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
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}
