//
//  CommunityMarkerView.swift
//  loc
//
//  Community place marker with selection state and pulsing animation
//

import SwiftUI

struct CommunityMarkerView: View {
    let emoji: String
    let fontSize: CGFloat
    let isSelected: Bool

    @State private var isPulsing = false

    /// Background circle diameter scaled from the emoji font size.
    private var circleSize: CGFloat {
        fontSize + 14
    }

    var body: some View {
        ZStack {
            // Pulsing rings when selected
            if isSelected {
                pulsingRings
            }

            // Google-style white circle background
            Circle()
                .fill(.white)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle()
                        .strokeBorder(.white, lineWidth: 1.5)
                )
                .shadow(
                    color: Color.black.opacity(0.25),
                    radius: isSelected ? 5 : 3,
                    x: 0,
                    y: 1.5
                )

            // Emoji marker
            Text(emoji)
                .font(.system(size: fontSize * 0.85))
        }
        .scaleEffect(isSelected ? 1.2 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .onChange(of: isSelected) { _, newValue in
            if newValue {
                isPulsing = false
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    isPulsing = true
                }
            } else {
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

    private var pulsingRings: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.blue.opacity(0.4), lineWidth: 2)
                .frame(width: circleSize + 8, height: circleSize + 8)
                .scaleEffect(isPulsing ? 1.6 : 1)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner pulsing ring
            Circle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                .frame(width: circleSize + 4, height: circleSize + 4)
                .scaleEffect(isPulsing ? 1.4 : 1)
                .opacity(isPulsing ? 0 : 0.8)
        }
    }
}
