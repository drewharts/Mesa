//
//  InlineToast.swift
//  loc
//
//  DUMB Component: a short message capsule shown near the bottom of a screen for transient errors.
//

import SwiftUI

/// Transient message capsule; the host decides when it appears.
struct InlineToast: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Capsule().fill(Color.black.opacity(0.85)))
            .padding(.horizontal, 16)
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            .accessibilityElement(children: .combine)
    }
}
