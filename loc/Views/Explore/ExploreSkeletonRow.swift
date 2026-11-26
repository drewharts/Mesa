//
//  ExploreSkeletonRow.swift
//  loc
//
//  DUMB Component: placeholder for a horizontal Explore section (title + a row of skeleton cards).
//

import SwiftUI

/// Same header and row structure as the real sections, so content swaps in without a layout jump.
struct ExploreSkeletonRow<Card: View>: View {
    let title: String
    var spacing: CGFloat = 12
    var count: Int = 4
    @ViewBuilder let card: () -> Card

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderRow(title: title)
                .redacted(reason: .placeholder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<count, id: \.self) { _ in card() }
                }
                .padding(.horizontal, 16)
            }
            .scrollDisabled(true)
        }
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading \(title)")
    }
}
