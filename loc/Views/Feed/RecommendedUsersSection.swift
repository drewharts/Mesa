//
//  RecommendedUsersSection.swift
//  loc
//
//  DUMB Component: Header + horizontal scroll row of recommended user cards.
//  Single Responsibility: Layout the recommended users section with dismiss capability.
//

import SwiftUI

struct RecommendedUsersSection: View {
    let users: [ProfileData]
    let followStates: [String: Bool]
    let isLoading: Bool
    let onFollowTap: (String) -> Void
    let onProfileTap: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        if isLoading {
            loadingView
        } else if !users.isEmpty {
            sectionContent
        }
    }

    // MARK: - Subviews

    private var sectionContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            userScrollRow
            Divider()
        }
        .padding(.top, 12)
    }

    private var header: some View {
        HStack {
            Text("Suggested for You")
                .font(.subheadline)
                .fontWeight(.semibold)
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }

    private var userScrollRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 14) {
                ForEach(users) { user in
                    RecommendedUserCard(
                        profile: user,
                        isFollowing: followStates[user.id] ?? false,
                        onFollowTap: { onFollowTap(user.id) },
                        onProfileTap: { onProfileTap(user.id) }
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    private var loadingView: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
    }
}
