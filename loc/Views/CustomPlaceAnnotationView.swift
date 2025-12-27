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
                        color: isSelected ? Color.blue.opacity(0.8) : Color.clear,
                        radius: isSelected ? 16 : 0,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isSelected ? 1.15 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Fallback to pin icon if no image
                Image(systemName: "mappin.circle.fill")
                    .font(.title)
                    .foregroundColor(isSelected ? .blue : .red)
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.8) : Color.clear,
                        radius: isSelected ? 16 : 0,
                        x: 0,
                        y: 0
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}

