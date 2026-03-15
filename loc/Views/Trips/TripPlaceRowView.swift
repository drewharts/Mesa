//
//  TripPlaceRowView.swift
//  loc
//
//  Single place row in the trip itinerary
//

import SwiftUI

/// Displays a numbered place entry with photo, name, and added-by info.
struct TripPlaceRowView: View {
    let place: TripDayPlace
    let number: Int

    var body: some View {
        HStack(spacing: 12) {
            // Number badge
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            // Place photo
            if let photoUrl = place.placePhoto, let url = URL(string: photoUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Place info
            VStack(alignment: .leading, spacing: 2) {
                Text(place.placeName ?? "Unknown Place")
                    .font(.body)
                    .lineLimit(1)

                if let address = place.placeAddress {
                    Text(address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let addedBy = place.addedByName {
                    Text("Added by \(addedBy)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            if let note = place.note, !note.isEmpty {
                Image(systemName: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
