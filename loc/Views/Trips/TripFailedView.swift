//
//  TripFailedView.swift
//  loc
//
//  Error state when trip creation fails
//

import SwiftUI

/// Shows error message with option to retry trip creation.
struct TripFailedView: View {
    let message: String
    let onRetry: () -> Void

    private let mesaCharcoal = Color(red: 45/255, green: 45/255, blue: 45/255)

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.title2)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                onRetry()
            } label: {
                Text("Try Again")
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
