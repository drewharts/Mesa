//
//  ExplorePersonSkeletonCard.swift
//  loc
//
//  DUMB Component: placeholder with the same layout as ExploreSuggestedPersonCard (round avatar, two
//  text lines, Follow button).
//

import SwiftUI

struct ExplorePersonSkeletonCard: View {
    private let avatarSize: CGFloat = 92

    var body: some View {
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                Circle().fill(SkeletonStyle.base).frame(width: avatarSize, height: avatarSize)
                Text("Person name").font(.subheadline.weight(.semibold))
                Text("Suggested for you").font(.caption)
            }
            .redacted(reason: .placeholder)
            Text("Follow")
                .font(.subheadline.weight(.semibold))
                .hidden()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(SkeletonStyle.base, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .padding(.top, 6)
        }
        .padding(.horizontal, 12)
        .padding(.top, 20)
        .padding(.bottom, 12)
        .frame(width: 150)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
