//
//  TripCreatingView.swift
//  loc
//
//  Loading state shown while trip is being created
//

import SwiftUI

/// Progress spinner displayed during trip creation.
struct TripCreatingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)

            Text("Creating your trip...")
                .font(.headline)

            Text("Setting up itinerary and adding collaborators")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
    }
}
