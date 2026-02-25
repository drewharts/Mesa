//
//  MapBottomNavigationBar.swift
//  loc
//
//  DUMB Component: Translucent bottom navigation bar for the map view
//  Single Responsibility: Render profile button + search capsule in a bottom bar
//
//  Layout: [Profile photo 36x36] [Search capsule button]
//

import SwiftUI

struct MapBottomNavigationBar: View {
    // MARK: - Dependencies

    @EnvironmentObject var profileViewModel: ProfileViewModel

    // MARK: - Bindings

    @Binding var showSearchPage: Bool
    @Binding var shouldNavigateToProfile: Bool

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()
            barContent
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Bar Content

    private var barContent: some View {
        HStack(spacing: 12) {
            profileButton
            searchCapsule
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
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
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
            }
        }
    }

    // MARK: - Search Capsule

    private var searchCapsule: some View {
        Button {
            showSearchPage = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))

                Text("Search places...")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.systemGray5).opacity(0.6))
            )
        }
    }
}
