//
//  FindTableStatusBar.swift
//  loc
//
//  DUMB Component: one line under the chip row while a table search is active. Shows what is being
//  shown ("Checked N places on Resy · M have tables") and a clear way back to the full list.
//

import SwiftUI

struct FindTableStatusBar: View {
    let text: String
    let isLoading: Bool
    /// Fraction checked (0...1) shown as a slim bar under the text while results stream in; nil hides it.
    var progress: Double? = nil
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                if isLoading { ProgressView().controlSize(.small) }
                Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button("Show all", action: onExit)
                    .font(.footnote.weight(.semibold))
            }
            if let progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(Color.mesaAccent)
                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}
