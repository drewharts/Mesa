//
//  TripItineraryPinView.swift
//  loc
//
//  Map annotation pin with numbered circle colored by day/stop
//

import SwiftUI

/// A numbered circle pin for trip map annotations with day-colored gradient.
struct TripItineraryPinView: View {
    let annotation: TripMapAnnotation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                numberCircle
                trianglePointer
                placeNameLabel
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .shadow(color: isSelected ? annotation.color.opacity(0.5) : .clear, radius: 6)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }

    /// Numbered circle filled with the stop's gradient-adjusted color.
    private var numberCircle: some View {
        Text("\(annotation.stopNumber)")
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Circle().fill(annotation.color))
    }

    /// Small triangle pointer below the circle.
    private var trianglePointer: some View {
        Triangle()
            .fill(annotation.color)
            .frame(width: 10, height: 6)
    }

    /// Place name label on a material background.
    private var placeNameLabel: some View {
        Text(annotation.placeName)
            .font(.caption2)
            .fontWeight(.medium)
            .lineLimit(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Triangle Shape

/// A downward-pointing triangle for the pin pointer.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
