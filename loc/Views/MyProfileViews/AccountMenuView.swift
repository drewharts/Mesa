//
//  AccountMenuView.swift
//  loc
//
//  Created by Claude on 12/11/24.
//

import SwiftUI

/// A toolbar menu component for account actions (edit profile, logout, delete account)
/// Single Responsibility: Manages account action UI presentation
/// MVVM: All state and logic managed by ProfileViewModel
struct AccountMenuView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showEditProfile = false

    var body: some View {
        Menu {
            editProfileButton
            logoutButton
            deleteAccountButton
        } label: {
            menuIcon
        }
        .sheet(isPresented: $showEditProfile) {
            if let user = profile.user {
                EditProfileView(user: user) { updatedUser in
                    profile.user = updatedUser
                }
            }
        }
    }

    // MARK: - Menu Items

    private var editProfileButton: some View {
        Button {
            showEditProfile = true
        } label: {
            Label("Edit Profile", systemImage: "pencil")
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            profile.logout()
        } label: {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }

    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            profile.accountViewModel.showDeleteWarning()
        } label: {
            Label("Delete Account", systemImage: "trash")
        }
    }

    private var menuIcon: some View {
        Image(systemName: "gearshape")
            .foregroundColor(.black)
            .font(.body)
    }
}
