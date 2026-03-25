//
//  TripTravelTimeConnectorView.swift
//  loc
//
//  Compact connector showing travel times between consecutive trip places
//

import SwiftUI

/// Displays travel time information between two consecutive places in a trip day itinerary.
struct TripTravelTimeConnectorView: View {
    let segment: TripTravelTimeSegment?

    /// Display order for transport modes.
    private let displayOrder: [MapKitService.TransportType] = [.automobile, .walking, .transit]

    var body: some View {
        VStack(spacing: 0) {
            connectorLine
            timeContent
            connectorLine
        }
        .frame(height: 40)
    }

    // MARK: - Subviews

    private var connectorLine: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.3))
            .frame(width: 1, height: 8)
    }

    @ViewBuilder
    private var timeContent: some View {
        if let segment = segment {
            if segment.isLoading {
                loadingView
            } else if segment.hasFailed || segment.travelTimes.isEmpty {
                failedView
            } else {
                travelTimesRow(segment.travelTimes)
            }
        } else {
            loadingView
        }
    }

    private var loadingView: some View {
        Text("...")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private var failedView: some View {
        Text("—")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    /// Renders available transport modes with icons and formatted times.
    private func travelTimesRow(_ times: [MapKitService.TransportType: TimeInterval]) -> some View {
        let modes = availableModes(from: times)
        return HStack(spacing: 6) {
            ForEach(Array(modes.enumerated()), id: \.element.id) { index, mode in
                if index > 0 {
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Label(
                    TripTravelTimesViewModel.formattedTime(from: mode.time),
                    systemImage: mode.type.iconName
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
                .labelStyle(CompactTravelLabelStyle())
            }
        }
    }

    /// Filters and orders transport modes that have results.
    private func availableModes(from times: [MapKitService.TransportType: TimeInterval]) -> [TravelMode] {
        displayOrder.compactMap { type in
            guard let time = times[type] else { return nil }
            return TravelMode(type: type, time: time)
        }
    }
}

// MARK: - Supporting Types

/// Pairs a transport type with its travel time for display.
private struct TravelMode: Identifiable {
    let type: MapKitService.TransportType
    let time: TimeInterval
    var id: Int { type.rawValue }
}

/// Compact label style with icon and text side by side.
private struct CompactTravelLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 2) {
            configuration.icon
                .font(.caption2)
            configuration.title
        }
    }
}
