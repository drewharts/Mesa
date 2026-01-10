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
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.5 : 0.3),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0) // Reduced from 1.5 to 1.2 for subtler selection
                    .zIndex(isSelected ? 100 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Fallback to pin icon if no image
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: isSelected ? 36 : 28)) // Reduced from 44 to 36 for subtler selection
                    .foregroundColor(.red)
                    .shadow(
                        color: Color.black.opacity(isSelected ? 0.5 : 0.3),
                        radius: isSelected ? 8 : 4,
                        x: 0,
                        y: isSelected ? 4 : 2
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}

