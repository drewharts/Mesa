//
//  SplashScreenView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//  Refactored to enterprise architecture on 11/13/25
//

import SwiftUI

struct SplashScreenView: View {
    @State private var isActive = false
    @State private var isCheckingSession = true
    @EnvironmentObject var userSession: UserSession
    
    // ViewModels passed as props, not environment objects
    let selectedPlaceViewModel: SelectedPlaceViewModel
    let profileViewModel: ProfileViewModel
    let userProfileViewModel: UserProfileViewModel
    let detailPlaceViewModel: DetailPlaceViewModel
    let deepLinkViewModel: DeepLinkViewModel
    let deepLinkManager: DeepLinkManager
    let notificationManager: NotificationManager
    let dataManager: DataManager
    let serviceContainer: ServiceContainer

    var body: some View {
        Group {
            if isActive {
                ContentView(
                    selectedPlaceViewModel: selectedPlaceViewModel,
                    profileViewModel: profileViewModel,
                    userProfileViewModel: userProfileViewModel,
                    detailPlaceViewModel: detailPlaceViewModel,
                    deepLinkViewModel: deepLinkViewModel,
                    deepLinkManager: deepLinkManager,
                    notificationManager: notificationManager,
                    dataManager: dataManager,
                    serviceContainer: serviceContainer
                )
                .transition(.opacity)
            } else {
                splashImage
            }
        }
        .task {
            // Check session during splash screen
            await checkSessionAndTransition()
        }
    }
    
    private var splashImage: some View {
        GeometryReader { geometry in
            Image("SplashScreen")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .edgesIgnoringSafeArea(.all)
    }
    
    private func checkSessionAndTransition() async {
        // Check for existing Supabase session
        do {
            let session = try await SupabaseAuthService.shared.getSession()
            let profile = try await UserService.shared.fetchUserById(userId: session.user.id.uuidString)
            
            // Set user logged in
            await MainActor.run {
                userSession.setUserLoggedIn(uid: profile.id)
            }
            
            // Load data in background
            Task.detached(priority: .background) {
                await dataManager.initializeProfileData(userId: profile.id)
            }
            
            // Quick transition for logged in users
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s
        } catch {
            // No session - show splash a bit longer
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
        }
        
        // Transition to main app
        await MainActor.run {
            withAnimation {
                isActive = true
            }
        }
    }
}
