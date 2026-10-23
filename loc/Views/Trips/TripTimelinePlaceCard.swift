//
//  TripTimelinePlaceCard.swift
//  loc
//
//  Photo-forward card for a place in the day itinerary
//

import SwiftUI

/// Displays a place as a photo-forward card with gradient overlay, stop badge, and metadata below.
struct TripDayPlaceCard: View {
    let place: TripDayPlace
    let number: Int
    let onTap: () -> Void

    private let cardHeight: CGFloat = 150

    /// Whether the full note is shown (notes collapse to 3 lines by default).
    @State private var isNoteExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            photoCard
            metadataSection
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    // MARK: - Photo Card

    private var photoCard: some View {
        ZStack(alignment: .bottomLeading) {
            photoBackground
            gradientOverlay
            placeInfoOverlay
            stopBadge
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    /// Place photo or hash-based fallback color.
    @ViewBuilder
    private var photoBackground: some View {
        if let photoUrl = place.placePhoto, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: cardHeight)
                    .clipped()
            } placeholder: {
                ShimmerView()
                    .frame(maxWidth: .infinity, maxHeight: cardHeight)
            }
        } else {
            fallbackColor
                .frame(maxWidth: .infinity, maxHeight: cardHeight)
                .overlay {
                    Image(systemName: "mappin.circle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.5))
                }
        }
    }

    /// Bottom-to-top gradient overlay for text readability.
    private var gradientOverlay: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.1), .black.opacity(0.2), .black.opacity(1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: cardHeight)
    }

    /// Place name and address overlaid on the gradient.
    private var placeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(place.placeName ?? "Unknown Place")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)

            if let address = place.placeAddress {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }

    /// Numbered stop badge in the top-left corner.
    private var stopBadge: some View {
        Text("\(number)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(Color.black.opacity(0.55))
            .clipShape(Circle())
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Metadata Below Card

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                if let time = TripNoteTime.time(in: place.note) {
                    Label(time, systemImage: "clock")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(Color.mesaAccent)
                }
                if let addedBy = place.addedByName {
                    Text("Added by \(addedBy)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let note = place.note, !note.isEmpty {
                Label(note, systemImage: "note.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .lineLimit(isNoteExpanded ? nil : 3)
                    .fixedSize(horizontal: false, vertical: true)

                if note.count > 110 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isNoteExpanded.toggle()
                        }
                    } label: {
                        Text(isNoteExpanded ? "less" : "more")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.mesaAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Helpers

    /// Hash-based hue fallback color when no photo is available.
    private var fallbackColor: Color {
        let hash = place.placeId.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
}
