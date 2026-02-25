//
//  ListOnboardingView.swift
//  loc
//
//  Fullscreen onboarding wrapper: presents GoogleMapsImportView with skip option.
//  Reuses the same import UI as the profile flow for consistent UX.
//

import SwiftUI

struct ListOnboardingView: View {
    @StateObject private var viewModel = ListOnboardingViewModel()
    @EnvironmentObject var userSession: UserSession

    @State private var showContent = false

    var body: some View {
        GoogleMapsImportView(
            userId: userSession.currentUserId ?? "",
            existingLists: viewModel.existingLists,
            onImportCompleted: { _ in
                userSession.completeListOnboarding()
            },
            cancelLabel: "Skip",
            onCancel: {
                userSession.completeListOnboarding()
            }
        )
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                showContent = true
            }
        }
        .task {
            await viewModel.fetchExistingLists(userId: userSession.currentUserId ?? "")
        }
    }
}
