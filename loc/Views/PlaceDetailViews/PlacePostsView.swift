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
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel

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
        // Post Button - Modern, sleek, inviting style with Apple glass
            Button(action: onAddPost) {
            HStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("Share something...")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.quaternary, lineWidth: 0.5)
            )
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

