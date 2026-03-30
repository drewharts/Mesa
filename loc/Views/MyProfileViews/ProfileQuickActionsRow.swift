//
//  ProfileQuickActionsRow.swift
//  loc
//
//  Prominent call-to-action for importing photos to discover places.
//

import SwiftUI

/// Action card displayed below the profile header to encourage photo import and taste profile.
struct ProfileQuickActionsRow: View {
    let onImportTap: () -> Void
    let onTasteTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
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

            Button(action: onTasteTap) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(red: 0.8, green: 0.4, blue: 0.1))
                    Text("My Taste")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(red: 0.8, green: 0.4, blue: 0.1).opacity(0.08))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }
}
