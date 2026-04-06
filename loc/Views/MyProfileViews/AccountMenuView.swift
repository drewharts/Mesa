//
//  AccountMenuView.swift
//  loc
//
//  Created by Claude on 12/11/24.
//

import SwiftUI

/// A toolbar menu component for account actions (edit profile, feedback, logout, delete account).
struct AccountMenuView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @State private var showEditProfile = false
    @State private var showFeedback = false

    var body: some View {
        Menu {
            editProfileButton
            feedbackButton
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
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(userId: userSession.currentUserId ?? "")
        }
    }

    // MARK: - Menu Items

    /// Opens the edit profile sheet.
    private var editProfileButton: some View {
        Button {
            showEditProfile = true
        } label: {
            Label("Edit Profile", systemImage: "pencil")
        }
    }

    /// Opens the feedback submission sheet.
    private var feedbackButton: some View {
        Button {
            showFeedback = true
        } label: {
            Label("Send Feedback", systemImage: "envelope")
        }
    }

    /// Logs the user out.
    private var logoutButton: some View {
        Button(role: .destructive) {
            profile.logout()
        } label: {
            Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
        }
    }

    /// Shows the delete account confirmation.
    private var deleteAccountButton: some View {
        Button(role: .destructive) {
            profile.accountViewModel.showDeleteWarning()
        } label: {
            Label("Delete Account", systemImage: "trash")
        }
    }

    /// Gear icon for the menu trigger.
    private var menuIcon: some View {
        Image(systemName: "gearshape")
            .foregroundColor(.black)
            .font(.body)
    }
}
