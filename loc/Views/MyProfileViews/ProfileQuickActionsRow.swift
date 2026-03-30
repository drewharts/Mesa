//
//  ProfileQuickActionsRow.swift
//  loc
//
//  Prominent call-to-action for importing photos to discover places.
//

import SwiftUI

/// Action card displayed below the profile header to encourage photo import.
struct ProfileQuickActionsRow: View {
    let onImportTap: () -> Void

    var body: some View {
        Button(action: onImportTap) {
            HStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Import Photos to Discover Places")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("We'll find the places you visited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
