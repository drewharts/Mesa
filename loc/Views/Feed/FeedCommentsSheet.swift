//
//  FeedCommentsSheet.swift
//  loc
//
//  SMART View: Comments sheet for feed items.
//  Single Responsibility: Present and manage comments for a feed card review.
//

import SwiftUI

struct FeedCommentsSheet: View {
    let item: FeedItem
    let currentUserId: String
    let currentUserProfile: ProfileData?
    let onDismissCount: (Int) -> Void
    let onProfileTapped: (String) -> Void

    @StateObject private var commentsViewModel = PostCommentsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                commentsScrollView
                Divider()
                commentInput
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            await commentsViewModel.fetchComments(reviewId: item.id)
        }
        .onDisappear {
            onDismissCount(commentsViewModel.comments.count)
        }
    }

    // MARK: - Comments Scroll View

    private var commentsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                postHeaderSection
                postCaptionSection
                postActionBarSection

                Divider()
                    .padding(.vertical, 4)

                commentsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    // MARK: - Post Header

    private var postHeaderSection: some View {
        HStack(alignment: .center, spacing: 12) {
            Button { onProfileTapped(item.userId) } label: {
                CachedProfileImage(
                    url: item.profilePhotoUrl,
                    size: 44,
                    fallbackInitial: String(item.userFirstName.prefix(1))
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(item.userFirstName) \(item.userLastName)")
                        .font(.headline)

                    if let wouldReturn = item.wouldReturn {
                        sentimentBadge(wouldReturn: wouldReturn)
                    }
                }

                Text(formattedTimestamp(item.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    // MARK: - Caption

    @ViewBuilder
    private var postCaptionSection: some View {
        if !item.caption.isEmpty {
            Text(item.caption)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Action Bar

    private var postActionBarSection: some View {
        PostActionBar(
            commentCount: commentsViewModel.comments.count,
            onCommentTapped: { }
        )
    }

    // MARK: - Comments Section

    @ViewBuilder
    private var commentsSection: some View {
        if commentsViewModel.isLoading {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 20)
        } else if commentsViewModel.comments.isEmpty {
            Text("No comments yet")
                .font(.subheadline)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
        } else {
            ForEach(commentsViewModel.comments) { comment in
                CommentRowView(
                    comment: comment,
                    isOwnComment: comment.userId == currentUserId,
                    onProfileTapped: { onProfileTapped(comment.userId) },
                    onDelete: {
                        Task {
                            await commentsViewModel.deleteComment(
                                commentId: comment.id,
                                reviewId: item.id,
                                placeId: item.placeId,
                                userId: currentUserId
                            )
                        }
                    }
                )
            }
        }
    }

    // MARK: - Comment Input

    private var commentInput: some View {
        CommentInputBar(
            text: $commentsViewModel.commentText,
            isSending: commentsViewModel.isSending,
            onSend: {
                Task {
                    await commentsViewModel.addComment(
                        reviewId: item.id,
                        placeId: item.placeId,
                        userId: currentUserId,
                        userFirstName: currentUserProfile?.firstName ?? "",
                        userLastName: currentUserProfile?.lastName ?? "",
                        profilePhotoUrl: currentUserProfile?.profilePhotoURL?.absoluteString ?? ""
                    )
                }
            }
        )
    }

    // MARK: - Helpers

    private func sentimentBadge(wouldReturn: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: wouldReturn ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                .font(.caption2)
            Text(wouldReturn ? "Would go back" : "Wouldn't revisit")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundColor(wouldReturn ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(wouldReturn ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

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
            return formatter.string(from: date)
        }
    }
}
