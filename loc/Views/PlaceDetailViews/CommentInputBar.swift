//
//  CommentInputBar.swift
//  loc
//
//  Text input and send button for adding comments
//

import SwiftUI

struct CommentInputBar: View {
    @Binding var text: String
    let isSending: Bool
    let onSend: () -> Void
    let replyingTo: Comment?
    let onCancelReply: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let reply = replyingTo {
                HStack {
                    Text("Replying to \(reply.userFirstName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button(action: onCancelReply) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
            }

            HStack(spacing: 10) {
                TextField(replyingTo != nil ? "Reply..." : "Add a comment...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)

                Button(action: onSend) {
                    if isSending {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}
