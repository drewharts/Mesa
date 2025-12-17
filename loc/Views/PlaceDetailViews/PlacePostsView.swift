//
//  PlacePostsView.swift
//  loc
//
//  Main view for displaying place posts feed
//

import SwiftUI

struct PlacePostsView: View {
    @ObservedObject var viewModel: PlacePostsViewModel
    let onPhotoTapped: ([UIImage], Int) -> Void
    let onAddPost: () -> Void
    let onAddNote: () -> Void
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileViewModel: UserProfileViewModel

    var body: some View {
        ScrollViewReader { scrollProxy in
            VStack(spacing: 24) {
                // Action Buttons Row
                postActionButtons
                
                switch viewModel.loadingState {
                case .loading:
                    ProgressView()
                        .padding()
                        .frame(maxWidth: .infinity)
                    
                case .loaded:
                    if viewModel.hasPosts {
                        PlacePostsListView(
                            viewModel: viewModel,
                            onPhotoTapped: onPhotoTapped,
                            scrollProxy: scrollProxy
                        )
                    } else {
                        emptyStateView
                    }
                    
                case .error(let error):
                    Text("Failed to load posts: \(error.localizedDescription)")
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding()
                    
                case .idle:
                    Text("Posts not yet loaded")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .onChange(of: viewModel.highlightedPostId) { _, postId in
                if let postId = postId {
                    scrollToPost(postId, proxy: scrollProxy)
                }
            }
        }
        .onAppear {
            viewModel.checkLikeStatuses()
        }
    }
    
    // MARK: - Action Buttons
    
    private var postActionButtons: some View {
        HStack(spacing: 10) {
            // Share Post Button
            Button(action: onAddPost) {
                HStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.caption)
                    Text("Share Post")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color(white: 0.45))
                .cornerRadius(16)
            }
            
            // Favorite Button
            Button(action: viewModel.toggleFavorite) {
                Image(systemName: viewModel.isFavorited ? "star.fill" : "star")
                    .font(.body)
                    .foregroundColor(viewModel.isFavorited ? .yellow : .gray)
                    .frame(width: 32, height: 32)
                    .background(viewModel.isFavorited ? Color.yellow.opacity(0.15) : Color.gray.opacity(0.1))
                    .cornerRadius(16)
            }
            
            // Private Note Button
            Button(action: onAddNote) {
                Image(systemName: "note.text")
                    .font(.body)
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(16)
            }
            
            Spacer()
        }
        .padding(.top, 8)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No posts yet")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Be the first to share your experience!")
                .font(.subheadline)
                .foregroundColor(.gray.opacity(0.7))
        }
        .padding(40)
    }
    
    private func scrollToPost(_ postId: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo(postId, anchor: .center)
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearHighlightedPost()
            }
        }
    }
}

