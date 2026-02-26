//
//  ContactsMatchSection.swift
//  loc
//
//  DUMB Component: Displays contact-matched profiles in the suggested profiles popup.
//  Single Responsibility: Render the "People in Your Contacts" section header and rows.
//

import SwiftUI

struct ContactsMatchSection: View {
    let contactMatches: [ProfileData]
    let isLoading: Bool
    let contactsAccessDenied: Bool
    let followStates: [String: Bool]
    let onProfileTap: (ProfileData) -> Void
    let onFollowTap: (String) -> Void

    var body: some View {
        if isLoading {
            loadingRow
        } else if contactsAccessDenied {
            accessDeniedRow
        } else if !contactMatches.isEmpty {
            contactsList
        }
    }

    // MARK: - Contacts List

    private var contactsList: some View {
        VStack(spacing: 0) {
            sectionHeader

            ForEach(contactMatches) { profile in
                SuggestedProfileRowView(
                    profile: profile,
                    isFollowing: followStates[profile.id] ?? false,
                    onTap: { onProfileTap(profile) },
                    onFollowTap: { onFollowTap(profile.id) }
                )
                .padding(.horizontal, 16)

                if profile.id != contactMatches.last?.id {
                    Divider()
                        .padding(.leading, 76)
                }
            }

            Divider()
        }
    }

    private var sectionHeader: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Text("People in Your Contacts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemGray6))
    }

    // MARK: - Loading

    private var loadingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Checking your contacts...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Access Denied

    private var accessDeniedRow: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                Text("Allow contacts access to find friends on Mesa")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}
