//
//  CustomPlaceAnnotationView.swift
//  loc
//
//  Custom map annotation showing user profile photos
//

import SwiftUI

struct CustomPlaceAnnotationView: View {
    let annotation: PlaceAnnotation
    let annotationImage: UIImage?
    let isSelected: Bool

    var body: some View {
        annotationContent
    }

    // MARK: - Annotation Content

    /// Number of users who saved this place.
    private var saverCount: Int { annotation.userIds.count }

    private var annotationContent: some View {
        VStack(spacing: 2) {
            if let annotationImage = annotationImage {
                Image(uiImage: annotationImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 30)
                    .overlay(alignment: .topTrailing) { saverBadge }
                    .shadow(color: isSelected ? Color.blue.opacity(0.8) : .clear, radius: 15)
                    .shadow(color: isSelected ? Color.blue.opacity(0.5) : .clear, radius: 25)
                    .shadow(color: isSelected ? Color.blue.opacity(0.3) : .clear, radius: 35)
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.5 : 0.3),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .zIndex(isSelected ? 100 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Fallback: show category emoji in a Google-style filled circle
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                        .overlay(
                            Circle()
                                .strokeBorder(.white, lineWidth: 2)
                        )
                        .shadow(
                            color: Color.black.opacity(0.25),
                            radius: isSelected ? 6 : 4,
                            x: 0,
                            y: 2
                        )

                    Text(PlaceTypeEmoji.emoji(for: annotation.placeType))
                        .font(.system(size: isSelected ? 24 : 19))
                }
                .overlay(alignment: .topTrailing) { saverBadge }
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }

    /// Small badge showing the number of friends who saved this place.
    @ViewBuilder
    private var saverBadge: some View {
        if saverCount > 1 {
            Text("\(saverCount)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(minWidth: 16, minHeight: 16)
                .background(Color(red: 0.8, green: 0.4, blue: 0.1))
                .clipShape(Circle())
                .offset(x: 6, y: -6)
        }
    }
}
