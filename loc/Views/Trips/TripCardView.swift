//
//  TripCardView.swift
//  loc
//
//  Card view displaying a single trip in the trips list.
//

import SwiftUI
import UIKit

/// Displays a single trip card with name, dates, and place count.
struct TripCardView: View {
    let trip: LightweightTrip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImageView
            tripInfoView
        }
        .frame(width: 160)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
    }

    /// Cover image or placeholder.
    private var coverImageView: some View {
        ZStack {
            if let coverUrl = trip.coverImage, let url = URL(string: coverUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholderView
                    case .empty:
                        ProgressView()
                    @unknown default:
                        placeholderView
                    }
                }
            } else {
                placeholderView
            }
        }
        .frame(width: 160, height: 100)
        .clipped()
        .cornerRadius(12, corners: [.topLeft, .topRight])
    }

    /// Placeholder when no cover image.
    private var placeholderView: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "airplane")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    /// Trip info section with name, dates, and place count.
    private var tripInfoView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(trip.name)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .lineLimit(1)

            Text(trip.formattedDateRange)
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 4) {
                Image(systemName: "mappin")
                    .font(.caption2)
                    .foregroundColor(.red)

                Text("\(trip.placeCount) \(trip.placeCount == 1 ? "place" : "places")")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}

