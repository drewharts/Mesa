//
//  FeedCardBackView.swift
//  loc
//
//  DUMB Component: Map side of a feed card (shown after flip).
//  Single Responsibility: Display place name header with a static map and pin.
//

import SwiftUI

struct FeedCardBackView: View {
    let item: FeedItem

    private var fullName: String {
        "\(item.userFirstName) \(item.userLastName)".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            mapSection
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.placeName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(fullName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Map

    private var mapSection: some View {
        Color.clear
            .aspectRatio(4.0 / 5.0, contentMode: .fit)
            .overlay(
                FeedCardMapView(
                    latitude: item.latitude,
                    longitude: item.longitude,
                    placeName: item.placeName
                )
            )
            .clipped()
    }
}
