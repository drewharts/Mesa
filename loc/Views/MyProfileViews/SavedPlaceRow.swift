//
//  SavedPlaceRow.swift
//  loc
//
//  DUMB Component: one saved place in a city list (type icon, name, one-line detail).
//

import SwiftUI

struct SavedPlaceRow: View {
    let name: String
    let detail: String
    let systemImage: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.mesaAccent)
                    .frame(width: 32, height: 32)
                    .background(Color.mesaAccent.opacity(0.1), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if !detail.isEmpty {
                        Text(detail).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
