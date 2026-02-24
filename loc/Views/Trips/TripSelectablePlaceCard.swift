//
//  TripSelectablePlaceCard.swift
//  loc
//
//  Selectable place tile for trip flows - mirrors PopupPlaceCard visual
//  with select/deselect toggle instead of navigation
//

import SwiftUI

/// Place tile card with selection toggle for trip place picking.
struct TripSelectablePlaceCard: View {
    let place: LightweightPlace
    let isSelected: Bool
    let onToggle: () -> Void
    var onDetailTap: (() -> Void)?

    // MARK: - Computed Properties

    private var placeColor: Color {
        let hash = place.place_id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }

    // MARK: - Body

    var body: some View {
        Rectangle()
            .fill(placeColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        TripSelectablePlaceCardPhoto(place: place, size: geometry.size)

                        LinearGradient(
                            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)

                        placeInfoOverlay
                    }
                }
            )
            .overlay(selectionOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture { onDetailTap?() }
    }

    // MARK: - Selection Overlay

    private var selectionOverlay: some View {
        ZStack(alignment: .topTrailing) {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 3)
            }

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .background(Circle().fill(.white).padding(2))
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
    }

    // MARK: - Place Info Overlay

    private var placeInfoOverlay: some View {
        Text(place.name)
            .font(.headline)
            .foregroundColor(.white)
            .lineLimit(1)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}
