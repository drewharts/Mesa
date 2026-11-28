//
//  ExplorePeopleSection.swift
//  loc
//
//  SMART Component: "Suggested for you" row backed by ExplorePeopleViewModel.
//

import SwiftUI

/// Horizontal row of suggested users with follow buttons.
struct ExplorePeopleSection: View {
    @ObservedObject var viewModel: ExplorePeopleViewModel
    let onProfileTap: (ProfileData) -> Void

    var body: some View {
        Group {
            if ScreenshotPrivacy.isActive {
                EmptyView()  // Suggested people are other users' faces; never shown in App Store screenshots.
            } else if !viewModel.people.isEmpty {
                content.transition(.opacity)
            } else if !viewModel.hasLoaded {
                ExploreSkeletonRow(title: "People to follow") { ExplorePersonSkeletonCard() }
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.25), value: viewModel.people.isEmpty)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeaderRow(title: "People to follow")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(viewModel.people) { person in
                        ExploreSuggestedPersonCard(
                            profile: person,
                            isFollowing: viewModel.followStates[person.id] ?? false,
                            onFollowTap: { Task { await viewModel.toggleFollow(profileId: person.id) } },
                            onProfileTap: { onProfileTap(person) },
                            onDismissTap: { viewModel.dismiss(profileId: person.id) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}
