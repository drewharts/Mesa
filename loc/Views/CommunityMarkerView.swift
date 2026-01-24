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

    var body: some View {
        ZStack {
            // Pulsing rings when selected
            if isSelected {
                pulsingRings
            }

            // Emoji marker
            Text(emoji)
                .font(.system(size: isSelected ? fontSize * 1.3 : fontSize))
                .shadow(color: isSelected ? Color.blue.opacity(0.8) : .black.opacity(0.3), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 0 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        }
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
                .frame(width: 40, height: 40)
                .scaleEffect(isPulsing ? 1.6 : 1)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner pulsing ring
            Circle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(isPulsing ? 1.4 : 1)
                .opacity(isPulsing ? 0 : 0.8)
        }
    }
}
