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
                    .background(
                        // Pulsing ring effect when selected
                        Circle()
                            .stroke(Color.blue, lineWidth: isSelected ? 3 : 0)
                            .frame(width: isSelected ? 80 : 0, height: isSelected ? 80 : 0)
                            .opacity(isSelected ? 0.6 : 0)
                    )
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.9) : Color.black.opacity(0.3),
                        radius: isSelected ? 20 : 4,
                        x: 0,
                        y: isSelected ? 0 : 2
                    )
                    .scaleEffect(isSelected ? 1.5 : 1.0)
                    .zIndex(isSelected ? 100 : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            } else {
                // Fallback to pin icon if no image
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: isSelected ? 44 : 28))
                    .foregroundColor(isSelected ? .blue : .red)
                    .background(
                        Circle()
                            .stroke(Color.blue, lineWidth: isSelected ? 3 : 0)
                            .frame(width: isSelected ? 60 : 0, height: isSelected ? 60 : 0)
                            .opacity(isSelected ? 0.6 : 0)
                    )
                    .shadow(
                        color: isSelected ? Color.blue.opacity(0.9) : Color.black.opacity(0.3),
                        radius: isSelected ? 16 : 4,
                        x: 0,
                        y: isSelected ? 0 : 2
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
        }
    }
}

