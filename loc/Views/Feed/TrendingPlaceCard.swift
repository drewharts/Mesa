//
//  TrendingPlaceCard.swift
//  loc
//
//  DUMB Component: A single card in the trending places horizontal scroll.
//

import SwiftUI

struct TrendingPlaceCard: View {
    let place: TrendingPlace
    let onTap: () -> Void



    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                photoSection
                infoSection
            }
            .frame(width: 160)
        }
        .buttonStyle(.plain)
    }

    private var photoSection: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let urlStr = place.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .overlay(
                            Text(PlaceTypeEmoji.emoji(for: place.placeType ?? "Place"))
                                .font(.system(size: 28))
                        )
                }
            }
            .frame(width: 160, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Crown badge
            HStack(spacing: 3) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 10))
                Text("\(place.crownCount)")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.mesaAccent)
            .clipShape(Capsule())
            .padding(6)
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.placeName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .lineLimit(1)
            if let city = place.city, !city.isEmpty {
                Text(city)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
