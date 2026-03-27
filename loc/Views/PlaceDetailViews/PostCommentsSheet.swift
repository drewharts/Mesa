//
//  PostCommentsSheet.swift
//  loc
//
//  Sheet displaying a post's content and its comments
//

import SwiftUI

struct PostCommentsSheet: View {
    let post: PlacePost
    @ObservedObject var postsViewModel: PlacePostsViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel
    @EnvironmentObject var profile: ProfileViewModel

    @StateObject private var commentsViewModel = PostCommentsViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                commentsScrollView
                Divider()
                commentInputSection
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
            await commentsViewModel.fetchComments(reviewId: post.id)
        }
    }

    // MARK: - Comments Scroll View

    private var commentsScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                postHeaderSection
                postTextSection
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
            postProfilePhoto

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(post.userFirstName) \(post.userLastName)")
                        .font(.headline)

                    if let wouldReturn = post.wouldReturn {
                        sentimentBadge(wouldReturn: wouldReturn)
                    }
                }

                Text(formattedTimestamp(post.timestamp))
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var postProfilePhoto: some View {
        if let photo = postsViewModel.photosViewModel.profilePhoto(forUserId: post.userId) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .foregroundColor(.gray)
        }
    }

    // MARK: - Post Text

    @ViewBuilder
    private var postTextSection: some View {
        if !post.text.isEmpty {
            Text(post.text)
                .font(.subheadline)
                .foregroundColor(.primary)
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
            ForEach(commentsViewModel.groupedComments, id: \.comment.id) { group in
                CommentRowView(
                    comment: group.comment,
                    isOwnComment: group.comment.userId == userSession.currentUserId,
                    onProfileTapped: {
                        navigateToProfile(userId: group.comment.userId)
                    },
                    onDelete: {
                        Task {
                            guard let userId = userSession.currentUserId else { return }
                            await commentsViewModel.deleteComment(commentId: group.comment.id, reviewId: post.id, placeId: post.placeId, userId: userId)
                        }
                    },
                    onReply: {
                        commentsViewModel.setReplyTarget(group.comment)
                    }
                )

                // Indented replies
                ForEach(group.replies) { reply in
                    CommentRowView(
                        comment: reply,
                        isOwnComment: reply.userId == userSession.currentUserId,
                        onProfileTapped: {
                            navigateToProfile(userId: reply.userId)
                        },
                        onDelete: {
                            Task {
                                guard let userId = userSession.currentUserId else { return }
                                await commentsViewModel.deleteComment(commentId: reply.id, reviewId: post.id, placeId: post.placeId, userId: userId)
                            }
                        },
                        onReply: {
                            commentsViewModel.setReplyTarget(group.comment)
                        }
                    )
                    .padding(.leading, 42)
                }
            }
        }
    }

    // MARK: - Comment Input

    private var commentInputSection: some View {
        CommentInputBar(
            text: $commentsViewModel.commentText,
            isSending: commentsViewModel.isSending,
            onSend: {
                Task {
                    guard let userId = userSession.currentUserId else { return }
                    let user = profile.user
                    let firstName = user?.firstName ?? ""
                    let lastName = user?.lastName ?? ""
                    let photoUrl = user?.profilePhotoURL?.absoluteString ?? ""
                    await commentsViewModel.addComment(
                        reviewId: post.id,
                        placeId: post.placeId,
                        userId: userId,
                        userFirstName: firstName,
                        userLastName: lastName,
                        profilePhotoUrl: photoUrl
                    )
                }
            },
            replyingTo: commentsViewModel.replyingTo,
            onCancelReply: { commentsViewModel.clearReplyTarget() }
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

    private func navigateToProfile(userId: String) {
        guard let currentUserId = userSession.currentUserId,
              userId != currentUserId else { return }
        userProfileNavigationVM.fetchAndSelectUser(userId: userId, currentUserId: currentUserId)
        dismiss()
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
