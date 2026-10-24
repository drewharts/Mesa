//
//  TripSkeletonViews.swift
//  loc
//
//  Shimmer placeholders that mirror the trips list, trip detail, and place detail
//  layouts so screens never show a blank spinner while loading.
//

import SwiftUI

// SkeletonBlock lives in Components/ShimmerView.swift (shared skeleton system).

/// Placeholder matching TripCardView rows in TripsListView.
struct TripsListSkeletonView: View {
    var count: Int = 4

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonBlock(width: 170, height: 16)
                                SkeletonBlock(width: 120, height: 12)
                            }
                            Spacer()
                            SkeletonBlock(width: 28, height: 28, cornerRadius: 14)
                        }
                        HStack(spacing: 16) {
                            SkeletonBlock(width: 70, height: 10)
                            SkeletonBlock(width: 60, height: 10)
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading trips")
    }
}

/// Placeholder matching the trip detail header + itinerary timeline.
/// Shows the real name/dates when known from the trips list.
struct TripDetailSkeletonView: View {
    let seed: LightweightTrip?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    if let seed {
                        Text(seed.name)
                            .font(.title2.weight(.bold))
                            .lineLimit(2)
                        Text(seed.dateRangeString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            Label("\(seed.placeCount) places", systemImage: "mappin")
                            Label("\(seed.numberOfDays) days", systemImage: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    } else {
                        SkeletonBlock(width: 200, height: 22)
                        SkeletonBlock(width: 140, height: 14)
                        SkeletonBlock(width: 160, height: 10)
                    }
                }

                // Day header
                SkeletonBlock(width: 150, height: 16)

                // Timeline rows
                ForEach(0..<min(max(seed?.placeCount ?? 4, 3), 6), id: \.self) { _ in
                    HStack(alignment: .top, spacing: 12) {
                        SkeletonBlock(width: 28, height: 28, cornerRadius: 14)
                        HStack(spacing: 12) {
                            SkeletonBlock(width: 56, height: 56, cornerRadius: 10)
                            VStack(alignment: .leading, spacing: 6) {
                                SkeletonBlock(width: 150, height: 14)
                                SkeletonBlock(width: 110, height: 10)
                                SkeletonBlock(height: 10)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .scrollDisabled(true)
        .accessibilityLabel("Loading trip")
    }
}

/// Placeholder matching the place detail sheet (title, info row, photos).
struct PlaceDetailSkeletonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SkeletonBlock(width: 220, height: 22)
            SkeletonBlock(width: 160, height: 12)
            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { _ in
                    SkeletonBlock(width: 64, height: 32, cornerRadius: 16)
                }
            }
            HStack(spacing: 8) {
                SkeletonBlock(height: 140, cornerRadius: 12)
                SkeletonBlock(height: 140, cornerRadius: 12)
            }
            SkeletonBlock(height: 12)
            SkeletonBlock(width: 240, height: 12)
            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("Loading place")
    }
}
