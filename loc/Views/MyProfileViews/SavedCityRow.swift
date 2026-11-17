//
//  SavedCityRow.swift
//  loc
//
//  DUMB Component: one entry per city (or smart group) on the Saved screen.
//

import SwiftUI

struct SavedCityRow: View {
    let title: String
    let subtitle: String
    let count: Int
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.mesaAccent)
                .frame(width: 36, height: 36)
                .background(Color.mesaAccent.opacity(0.1), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.primary).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text("\(count)").font(.subheadline).foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}
