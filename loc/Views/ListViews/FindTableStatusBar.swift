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
    let onExit: () -> Void

    var body: some View {
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
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}
