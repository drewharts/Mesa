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

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Pulsing rings when selected (behind the annotation)
            if isSelected {
                pulsingRings
            }

            // Main annotation content
            annotationContent
        }
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                // Start pulsing animation when selected
                isPulsing = false
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
                // Reset when deselected
                isPulsing = false
            }
        }
        .onAppear {
            if isSelected {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            }
        }
    }

    // MARK: - Pulsing Rings

    private var pulsingRings: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: 50, height: 50)
                .scaleEffect(isPulsing ? 1.8 : 1)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner pulsing ring
            Circle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(isPulsing ? 1.5 : 1)
                .opacity(isPulsing ? 0 : 0.8)
        }
        .offset(y: -15) // Center rings on the annotation (accounting for anchor at bottom)
    }

    // MARK: - Annotation Content

    private var annotationContent: some View {
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
