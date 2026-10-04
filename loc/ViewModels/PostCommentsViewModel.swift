//
//  PostCommentsViewModel.swift
//  loc
//
//  ViewModel for managing comments on a post
//

import Foundation
import Combine

@MainActor
class PostCommentsViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var isLoading: Bool = false
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
    private let reviewId: String
    private let postService = ServiceContainer.shared.supabasePostService
    private let postsCacheService = PlacePostsCacheService.shared
    private let commentsCacheService = CommentsCacheService.shared
    private var cancellables = Set<AnyCancellable>()

    init(reviewId: String) {
        self.reviewId = reviewId
        commentsCacheService.$commentsCache
            .map { $0[reviewId] ?? [] }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .assign(to: &$comments)
    }

    // MARK: - Actions

    /// Loads this review's comments. Renders instantly from cache if already fetched this
    /// session (subscription above updates `comments` as soon as the cache is populated),
    /// then refreshes from network to pick up anything new.
    func fetchComments() async {
        isLoading = !commentsCacheService.isCached(forReviewId: reviewId)
        await commentsCacheService.loadComments(reviewId: reviewId)
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

    /// Adds a new comment to the review and appends it to the shared cache.
    func addComment(placeId: String, userId: String, userFirstName: String, userLastName: String, profilePhotoUrl: String) async {
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
            commentsCacheService.addComment(comment, toReviewId: reviewId)
            commentText = ""
            replyingTo = nil
            postsCacheService.incrementCommentCount(forPostId: reviewId, inPlaceId: placeId)
        } catch {
            print("Failed to add comment: \(error)")
        }
        isSending = false
    }

    /// Deletes a comment if the current user owns it and removes it from the shared cache.
    func deleteComment(commentId: String, placeId: String, userId: String) async {
        guard let comment = comments.first(where: { $0.id == commentId }),
              comment.userId == userId else { return }

        do {
            try await postService.deleteComment(commentId: commentId)
            commentsCacheService.removeComment(commentId: commentId, fromReviewId: reviewId)
            postsCacheService.decrementCommentCount(forPostId: reviewId, inPlaceId: placeId)
        } catch {
            print("Failed to delete comment: \(error)")
        }
    }
}
