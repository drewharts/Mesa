//
//  BottomNavigationBar.swift
//  loc
//
//  Apple Music-style bottom navigation bar for map view
//  Replaces FloatingActionButtons with profile, search, and trips entry points
//

import SwiftUI

/// Translucent bottom navigation bar with profile, search, and trips buttons.
struct BottomNavigationBar: View {
    // MARK: - Dependencies

    @EnvironmentObject var profileViewModel: ProfileViewModel

    // MARK: - Bindings

    @Binding var showSearchPage: Bool
    @Binding var shouldNavigateToProfile: Bool
    @Binding var shouldNavigateToFeed: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: 16) {
            feedButton
            tripsButton
            searchCapsule
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

    // MARK: - Feed Button

    private var feedButton: some View {
        Button {
            shouldNavigateToFeed = true
        } label: {
            Image("MesaLogo")
                .resizable()
                .scaledToFill()
                .frame(width: 36, height: 36)
                .clipShape(Circle())
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Button {
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
            showSearchPage = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Search places...")
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

    // MARK: - Trips Button

    private var tripsButton: some View {
        Button {
            PresentationService.shared.present(.tripsList)
        } label: {
            Image(systemName: "airplane")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5).opacity(0.6))
                .clipShape(Circle())
        }
    }
}
