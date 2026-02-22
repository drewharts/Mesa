//
//  PostActionBar.swift
//  loc
//
//  Action bar with comment button for posts
//

import SwiftUI

struct PostActionBar: View {
    let commentCount: Int
    let onCommentTapped: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onCommentTapped) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
            }

            if commentCount > 0 {
                Text("\(commentCount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }

            Spacer()
        }
    }
}
