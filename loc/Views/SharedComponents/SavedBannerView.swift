//
//  SavedBannerView.swift
//  loc
//
//  Low-key "Added to {City}" confirmation with the one secondary action: change or add another list.
//  Shared by the place page one-tap save and the import flows.
//

import SwiftUI

struct SavedBannerView: View {
    let message: String
    var isError: Bool = false
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? .red : .mesaAccent)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            if !isError {
                Button("Change", action: onChange)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.mesaAccent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mesaAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
