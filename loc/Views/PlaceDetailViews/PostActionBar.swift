//
//  PostActionBar.swift
//  loc
//
//  Action bar with like button and count for posts
//

import SwiftUI

struct PostActionBar: View {
    let likeCount: Int
    let isLiked: Bool
    let isOwnPost: Bool
    let onLikeTapped: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: {
                if !isOwnPost {
                    onLikeTapped()
                }
            }) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22))
                    .foregroundColor(isOwnPost ? .gray.opacity(0.4) : (isLiked ? .red : .primary))
            }
            .disabled(isOwnPost)

            if likeCount > 0 {
                Text("\(likeCount) \(likeCount == 1 ? "like" : "likes")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}
