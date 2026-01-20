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
        VStack(spacing: 2) {
            if let annotationImage = annotationImage {
                Image(uiImage: annotationImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 30)
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
                // Fallback: show category emoji based on place type
                Text(PlaceTypeEmoji.emoji(for: annotation.placeType))
                    .font(.system(size: isSelected ? 32 : 24))
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
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}

