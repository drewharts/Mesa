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

    private var annotationContent: some View {
        VStack(spacing: 2) {
            if let annotationImage = annotationImage {
                Image(uiImage: annotationImage)
                    .interpolation(.medium)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 30)
                    .compositingGroup()
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.6) : Color.black.opacity(0.3),
                        radius: isSelected ? 12 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Fallback: show category emoji in a Google-style filled circle
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: isSelected ? 46 : 38, height: isSelected ? 46 : 38)
                        .shadow(
                            color: Color.black.opacity(0.25),
                            radius: isSelected ? 6 : 4,
                            x: 0,
                            y: 2
                        )

                    Text(PlaceTypeEmoji.emoji(for: annotation.placeType))
                        .font(.system(size: isSelected ? 24 : 19))
                }
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}
