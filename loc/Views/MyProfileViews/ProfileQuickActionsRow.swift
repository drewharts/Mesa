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
                    .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))

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
            .background(Color(red: 0.8, green: 0.4, blue: 0.1).opacity(0.08))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }
}
