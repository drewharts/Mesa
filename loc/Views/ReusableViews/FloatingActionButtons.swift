//
//  FloatingActionButtons.swift
//  loc
//
//  Floating action buttons for search and profile navigation
//

import SwiftUI

/// Floating action buttons for map view
/// Single Responsibility: Display search and profile FABs
struct FloatingActionButtons: View {
    // MARK: - Dependencies

    @EnvironmentObject var profileViewModel: ProfileViewModel

    // MARK: - Bindings

    @Binding var showSearchPage: Bool
    @Binding var shouldNavigateToProfile: Bool

    // MARK: - Body

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    searchButton
                    profileButton
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
        }
    }

    // MARK: - Search Button

    private var searchButton: some View {
        Button(action: {
            showSearchPage = true
        }) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .frame(width: 60, height: 60)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                .shadow(radius: 4)
        }
    }

    // MARK: - Profile Button

    private var profileButton: some View {
        Group {
            if let profilePhoto = profileViewModel.userPicture {
                Image(uiImage: profilePhoto)
                    .resizable()
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            } else {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
            }
        }
        .contentShape(Circle())
        .gesture(
            TapGesture()
                .onEnded { _ in
                    shouldNavigateToProfile = true
                },
            including: .all
        )
    }
}
