//
//  PlacePostsListView.swift
//  loc
//
//  Displays the list of posts for a place
//

import SwiftUI
import UIKit

struct PlacePostsListView: View {
    @ObservedObject var viewModel: PlacePostsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    let scrollProxy: ScrollViewProxy
    
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userSession: UserSession
    
    @State private var postToDelete: PlacePost? = nil
    @State private var showDeleteConfirmation = false

    var body: some View {
        ForEach(viewModel.posts, id: \.id) { post in
            PlacePostView(
                post: post,
                viewModel: viewModel,
                onPhotoTapped: onPhotoTapped
            )
            .id(post.id)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(viewModel.highlightedPostId == post.id ?
                        Color.blue.opacity(0.1) : Color.white)
            .cornerRadius(10)
            .animation(.easeInOut(duration: 0.3), value: viewModel.highlightedPostId)
            .onLongPressGesture(minimumDuration: 0.5) {
                // Only allow deletion if this is the user's own post
                if post.userId == userSession.currentUserId {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                    
                    postToDelete = post
                    showDeleteConfirmation = true
                }
            }
        }
        .alert("Delete Post", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                postToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let post = postToDelete {
                    deletePost(post)
                }
            }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
    }
    
    private func deletePost(_ post: PlacePost) {
        selectedPlaceVM.deletePost(postId: post.id) { result in
            switch result {
            case .success:
                print("Post deleted successfully")
            case .failure(let error):
                print("Failed to delete post: \(error.localizedDescription)")
            }
        }
        postToDelete = nil
    }
}

