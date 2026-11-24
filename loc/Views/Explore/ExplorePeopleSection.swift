//
//  ExplorePeopleSection.swift
//  loc
//
//  SMART Component: "People to follow" row backed by ExplorePeopleViewModel.
//

import SwiftUI

/// Horizontal row of suggested users with follow buttons.
struct ExplorePeopleSection: View {
    @ObservedObject var viewModel: ExplorePeopleViewModel
    let onProfileTap: (String) -> Void

    var body: some View {
        if !viewModel.people.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeaderRow(title: "People to follow")
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(viewModel.people) { person in
                            RecommendedUserCard(
                                profile: person,
                                isFollowing: viewModel.followStates[person.id] ?? false,
                                onFollowTap: { Task { await viewModel.toggleFollow(profileId: person.id) } },
                                onProfileTap: { onProfileTap(person.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }
}
