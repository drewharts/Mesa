//
//  GlassComposerButton.swift
//  loc
//
//  Shared "start a post" composer-style button (frosted glass, tappable text field look).
//

import SwiftUI

struct GlassComposerButton: View {
    let icon: String
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                Text(text)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 16) {
        GlassComposerButton(icon: "plus", text: "Share something...", action: {})
        GlassComposerButton(icon: "square.and.pencil", text: "Write a Review", action: {})
    }
    .padding()
}
