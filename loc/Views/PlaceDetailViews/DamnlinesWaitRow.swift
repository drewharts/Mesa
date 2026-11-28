//
//  DamnlinesWaitRow.swift
//  loc
//
//  Wait-time summary with the CC BY 4.0 attribution link to the damnlines venue page.
//

import SwiftUI

struct DamnlinesWaitRow: View {
    let info: DamnlinesWaitInfo

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(info.summaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("Wait data:")
                    .foregroundStyle(.secondary)
                Button("damnlines") { openURL(info.pageURL) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                    .accessibilityHint("Opens the damnlines page for \(info.venueName)")
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("place.detail.damnlinesWait")
    }
}
