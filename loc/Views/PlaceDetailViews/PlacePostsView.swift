//
//  PlacePostsView.swift
//  loc
//
//  Main view for displaying place posts feed
//

import SwiftUI

struct PlacePostsView: View {
    @ObservedObject var viewModel: PlacePostsViewModel
    
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var userProfileNavigationVM: UserProfileNavigationViewModel

    /// Posts/reviews section; collapses entirely when there are no posts
    /// (the Review action in the info section is the call to add the first one).
    var body: some View {
        ScrollViewReader { scrollProxy in
            if viewModel.hasPosts {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reviews")
                        .font(.headline)
                    PlacePostsListView(
                        viewModel: viewModel,
                        scrollProxy: scrollProxy
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("place.detail.posts")
                .onChange(of: viewModel.highlightedPostId) { _, postId in
                    if let postId = postId {
                        scrollToPost(postId, proxy: scrollProxy)
                    }
                }
            }
        }
        .onAppear {
            viewModel.checkLikeStatuses()
        }
    }
    
    /// Scrolls to the highlighted post and triggers auto-open comments after the animation settles.
    private func scrollToPost(_ postId: String, proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                proxy.scrollTo(postId, anchor: .center)
            }

            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                viewModel.triggerAutoOpenComments(for: postId)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                viewModel.clearHighlightedPost()
            }
        }
    }
}

