//
//  PostCommentsViewModel.swift
//  loc
//
//  ViewModel for managing comments on a post
//

import Foundation

@MainActor
class PostCommentsViewModel: ObservableObject {
    // MARK: - Published State
    @Published var comments: [Comment] = []
    @Published var isLoading: Bool = false
    @Published var commentText: String = ""
    @Published var isSending: Bool = false
    @Published var replyingTo: Comment?

    /// Groups comments: top-level comments with their replies nested below.
    var groupedComments: [(comment: Comment, replies: [Comment])] {
        let topLevel = comments.filter { $0.parentCommentId == nil }
        return topLevel.map { parent in
            let replies = comments.filter { $0.parentCommentId == parent.id }
            return (comment: parent, replies: replies)
        }
    }

    // MARK: - Dependencies
    private let postService = ServiceContainer.shared.supabasePostService
    private let postsCacheService = PlacePostsCacheService.shared

    // MARK: - Actions

    /// Fetches all comments for a given review.
    func fetchComments(reviewId: String) async {
        isLoading = true
        do {
            comments = try await postService.fetchComments(reviewId: reviewId)
        } catch {
            print("Failed to fetch comments: \(error)")
        }
        isLoading = false
    }

    /// Sets the comment being replied to.
    func setReplyTarget(_ comment: Comment) {
        replyingTo = comment
    }

    /// Clears the reply target back to top-level comment mode.
    func clearReplyTarget() {
        replyingTo = nil
    }

    /// Adds a new comment to the review and appends it to the local array.
    func addComment(reviewId: String, placeId: String, userId: String, userFirstName: String, userLastName: String, profilePhotoUrl: String) async {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSending = true
        do {
            let comment = try await postService.addComment(
                reviewId: reviewId,
                placeId: placeId,
                userId: userId,
                text: trimmed,
                userFirstName: userFirstName,
                userLastName: userLastName,
                profilePhotoUrl: profilePhotoUrl,
                parentCommentId: replyingTo?.id
            )
            comments.append(comment)
            commentText = ""
            replyingTo = nil
            postsCacheService.incrementCommentCount(forPostId: reviewId, inPlaceId: placeId)
        } catch {
            print("Failed to add comment: \(error)")
        }
        isSending = false
    }

    /// Deletes a comment if the current user owns it and removes it from the local array.
    func deleteComment(commentId: String, reviewId: String, placeId: String, userId: String) async {
        guard let comment = comments.first(where: { $0.id == commentId }),
              comment.userId == userId else { return }

        do {
            try await postService.deleteComment(commentId: commentId)
            comments.removeAll { $0.id == commentId }
            postsCacheService.decrementCommentCount(forPostId: reviewId, inPlaceId: placeId)
        } catch {
            print("Failed to delete comment: \(error)")
        }
    }
}
