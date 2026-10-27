//
//  TonightPickCardSkeleton.swift
//  loc
//
//  DUMB: shimmer placeholder matching TonightPickCard's layout.
//

import SwiftUI

struct TonightPickCardSkeleton: View {
    var body: some View {
        HStack(spacing: 14) {
            SkeletonBlock(width: 64, height: 64, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 160, height: 16, cornerRadius: 6)
                SkeletonBlock(width: 220, height: 12, cornerRadius: 6)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
