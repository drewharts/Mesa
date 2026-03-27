//
//  CommentRowView.swift
//  loc
//
//  Displays a single comment in the comments list
//

import SwiftUI

struct CommentRowView: View {
    let comment: Comment
    let isOwnComment: Bool
    let onProfileTapped: () -> Void
    let onDelete: () -> Void
    let onReply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                profileImage

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("\(comment.userFirstName) \(comment.userLastName)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(formattedTimestamp)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(comment.commentText)
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    Button(action: onReply) {
                        Text("Reply")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(.vertical, 6)
        .contextMenu {
            if isOwnComment {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private var profileImage: some View {
        Group {
            if let url = URL(string: comment.profilePhotoUrl), !comment.profilePhotoUrl.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .onTapGesture { onProfileTapped() }
    }

    private var formattedTimestamp: String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: comment.timestamp, to: now)

        let minutes = components.minute ?? 0
        let hours = components.hour ?? 0
        let days = components.day ?? 0

        if days < 0 || hours < 0 || minutes < 0 { return "Just now" }

        if days == 0 && hours == 0 && minutes < 60 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if days == 0 && hours < 24 {
            return "\(hours)h"
        } else if days > 0 {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: comment.timestamp)
        }
    }
}
