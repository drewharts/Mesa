//
//  PulsingBeaconView.swift
//  loc
//
//  Sleek pulsing beacon marker for selected places
//

import SwiftUI

struct PulsingBeaconView: View {
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulsing ring
            Circle()
                .stroke(Color.white.opacity(0.6), lineWidth: 2)
                .frame(width: 40, height: 40)
                .scaleEffect(isPulsing ? 1.5 : 1)
                .opacity(isPulsing ? 0 : 0.8)

            // Inner pulsing ring
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 2)
                .frame(width: 30, height: 30)
                .scaleEffect(isPulsing ? 1.3 : 1)
                .opacity(isPulsing ? 0 : 0.8)

            // Center dot
            Circle()
                .fill(Color(white: 0.2))
                .frame(width: 14, height: 14)
                .scaleEffect(isPulsing ? 1.15 : 1.0, anchor: .center)
                .shadow(color: .black.opacity(0.3), radius: 2)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                isPulsing = true
            }
        }
    }
}
