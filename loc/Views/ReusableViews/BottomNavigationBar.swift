//
//  BottomNavigationBar.swift
//  loc
//
//  Apple Music-style bottom navigation bar for map view
//  Replaces FloatingActionButtons with profile, search, and trips entry points
//

import SwiftUI

/// Translucent bottom navigation bar: search, Tonight (primary action), profile avatar.
/// Feed and Trips live in the profile (ProfileShortcutsRow) since 4.92.
struct BottomNavigationBar: View {
    // MARK: - Dependencies

    @EnvironmentObject var profileViewModel: ProfileViewModel

    // MARK: - Bindings

    @Binding var showSearchPage: Bool
    @Binding var shouldNavigateToProfile: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            searchCapsule
            tonightButton
            profileButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button {
            Analytics.track(.navTapped, ["item": "profile", "from": "map"])
            shouldNavigateToProfile = true
        } label: {
            Group {
                if let profilePhoto = profileViewModel.userPicture {
                    Image(uiImage: profilePhoto)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(Circle())
        }
    }

    // MARK: - Search Capsule

    private var searchCapsule: some View {
        Button {
            Analytics.track(.navTapped, ["item": "search", "from": "map"])
            showSearchPage = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Search")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray5).opacity(0.6))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tonight Button

    private var tonightButton: some View {
        Button {
            Analytics.track(.navTapped, ["item": "tonight", "from": "map"])
            PresentationService.shared.present(.tonight)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text("Tonight")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 40)
            .background(Color.mesaAccent)
            .clipShape(Capsule())
            .shadow(color: Color.mesaAccent.opacity(0.35), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tonight")
    }
}
