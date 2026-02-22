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

    // MARK: - Dependencies
    private let postService = ServiceContainer.shared.supabasePostService

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
                profilePhotoUrl: profilePhotoUrl
            )
            comments.append(comment)
            commentText = ""
        } catch {
            print("Failed to add comment: \(error)")
        }
        isSending = false
    }

    /// Deletes a comment if the current user owns it and removes it from the local array.
    func deleteComment(commentId: String, userId: String) async {
        guard let comment = comments.first(where: { $0.id == commentId }),
              comment.userId == userId else { return }

        do {
            try await postService.deleteComment(commentId: commentId)
            comments.removeAll { $0.id == commentId }
        } catch {
            print("Failed to delete comment: \(error)")
        }
    }
}
