//
//  SavedBannerView.swift
//  loc
//
//  Low-key "Saved to …" confirmation with the one secondary action: add it to a list too.
//  Shared by the place page one-tap save and the import flows.
//

import SwiftUI

struct SavedBannerView: View {
    let message: String
    let onAddToList: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.mesaAccent)
            Text(message)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(1)
            Spacer(minLength: 8)
            Button("Add to list", action: onAddToList)
                .font(.footnote.weight(.semibold))
                .foregroundColor(.mesaAccent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mesaAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
