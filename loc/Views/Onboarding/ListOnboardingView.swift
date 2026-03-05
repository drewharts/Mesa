//
//  ListOnboardingView.swift
//  loc
//
//  Fullscreen onboarding wrapper: presents GoogleMapsImportView with skip option.
//  Reuses the same import UI as the profile flow for consistent UX.
//

import SwiftUI

struct ListOnboardingView: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel

    @State private var showContent = false

    var body: some View {
        GoogleMapsImportView(onClose: {
            userSession.completeListOnboarding()
        })
        .environmentObject(profile)
        .opacity(showContent ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                showContent = true
            }
        }
    }
}
