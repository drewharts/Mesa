//
//  ExploreListSkeletonCard.swift
//  loc
//
//  DUMB Component: placeholder with the same layout as ExploreListCard (3:4 cover + two caption lines).
//

import SwiftUI

struct ExploreListSkeletonCard: View {
    /// Fixed card width for horizontal rows; nil lets the card fill a grid cell.
    var width: CGFloat? = ExploreCoverMetrics.card.width

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
                .aspectRatio(3.0 / 4.0, contentMode: .fit)
            VStack(alignment: .leading, spacing: 2) {
                Text("List name").font(.subheadline).fontWeight(.semibold)
                Text("0 places").font(.caption)
            }
            .redacted(reason: .placeholder)
        }
        .frame(width: width)
    }
}
