//
//  TripItineraryPinView.swift
//  loc
//
//  Map annotation pin styled like regular annotations with day-colored border and stop badge
//

import SwiftUI

/// A place-type emoji pin for trip map annotations with a day-colored border and stop number badge.
struct TripItineraryPinView: View {
    let annotation: TripMapAnnotation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                emojiCircle
                stopBadge
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.15 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
    }

    /// White circle with place-type emoji and a colored border indicating the day.
    private var emojiCircle: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                .overlay(
                    Circle()
                        .strokeBorder(annotation.color, lineWidth: 3)
                )
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: isSelected ? 6 : 4,
                    x: 0,
                    y: 2
                )

            Text(PlaceTypeEmoji.emoji(for: annotation.placeType ?? ""))
                .font(.system(size: isSelected ? 24 : 19))
        }
    }

    /// Small numbered badge in the corner showing the stop order.
    private var stopBadge: some View {
        Text("\(annotation.stopNumber)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 18, height: 18)
            .background(Circle().fill(annotation.color))
            .offset(x: 4, y: -4)
    }
}
