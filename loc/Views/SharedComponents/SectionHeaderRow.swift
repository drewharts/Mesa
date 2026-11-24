//
//  SectionHeaderRow.swift
//  loc
//
//  DUMB Component: Section title with an optional subtitle, used by scrolling feed-style screens.
//

import SwiftUI

/// Bold section title with an optional secondary line.
struct SectionHeaderRow: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
}
