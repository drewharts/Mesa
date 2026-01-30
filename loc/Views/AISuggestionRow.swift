//
//  AISuggestionRow.swift
//  loc
//
//  DUMB Component: Displays a single AI suggestion with photo
//

import SwiftUI

/// DUMB Component: Displays a single AI-suggested place
/// Single Responsibility: Render place info with photo and AI reasoning
struct AISuggestionRow: View {
    let place: DetailPlace
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                placeImage

                VStack(alignment: .leading, spacing: 4) {
                    placeNameRow
                    addressRow
                    aiReasoningRow
                }

                Spacer()

                ratingBadge
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Subviews

    /// Renders the place photo or a gradient fallback icon
    @ViewBuilder
    private var placeImage: some View {
        if let photoUrl = place.photoUrls?.first, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    fallbackIcon
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                @unknown default:
                    fallbackIcon
                }
            }
        } else {
            fallbackIcon
        }
    }

    /// Renders the fallback sparkles icon when no photo is available
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [.purple.opacity(0.6), .blue.opacity(0.6)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 60, height: 60)

            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    /// Renders the place name with a sparkles indicator
    private var placeNameRow: some View {
        HStack(spacing: 4) {
            Text(place.name)
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.black)
                .lineLimit(1)

            Image(systemName: "sparkles")
                .font(.system(size: 10))
                .foregroundColor(.purple)
        }
    }

    /// Renders the place address if available
    @ViewBuilder
    private var addressRow: some View {
        if let address = place.address, !address.isEmpty {
            Text(address)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }

    /// Renders the AI reasoning text explaining why this place was suggested
    @ViewBuilder
    private var aiReasoningRow: some View {
        if let reason = place.aiSuggestionReason, !reason.isEmpty {
            Text(reason)
                .font(.caption)
                .italic()
                .foregroundColor(.purple.opacity(0.8))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Renders the rating and price level badge
    @ViewBuilder
    private var ratingBadge: some View {
        if let rating = place.rating {
            VStack(spacing: 2) {
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)

                    Text(String(format: "%.1f", rating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }

                if let priceLevel = place.priceLevel, !priceLevel.isEmpty {
                    Text(priceLevel)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
