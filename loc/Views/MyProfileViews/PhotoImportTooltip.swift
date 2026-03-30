//
//  PhotoImportTooltip.swift
//  loc
//
//  First-time coach mark tooltip pointing users to the photo import feature.
//

import SwiftUI

/// Floating tooltip that explains the photo import feature on first profile visit.
struct PhotoImportTooltip: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            tooltipArrow
            tooltipBody
        }
        .onTapGesture { onDismiss() }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { onDismiss() }
        }
    }

    private var tooltipArrow: some View {
        Triangle()
            .fill(Color(.systemBackground))
            .frame(width: 16, height: 8)
            .shadow(color: .black.opacity(0.08), radius: 4, y: -2)
    }

    private var tooltipBody: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))

            Text("Import your photos and we'll find the places you've been!")
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(2)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }

}

/// Simple triangle shape for the tooltip arrow.
private struct Triangle: Shape {
    /// Draws a triangle pointing upward.
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
