//
//  UserSession.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/11/24.
//

import GoogleSignIn
import SwiftUI
import Supabase

class UserSession: ObservableObject {
    @Published var isUserLoggedIn: Bool = false
    @Published var profileViewModel: ProfileViewModel?
    @Published var currentUserId: String?
    @Published var needsProfilePhoto: Bool = false
    @Published var needsListOnboarding: Bool = false

    private static let hasCompletedPhotoOnboardingKey = "hasCompletedProfilePhotoOnboarding"
    private static let hasCompletedListOnboardingKey = "hasCompletedListOnboarding"

    /// Checks whether the user has completed profile photo onboarding.
    static var hasCompletedPhotoOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedPhotoOnboardingKey)
    }

    /// Checks whether the user has completed list creation onboarding.
    static var hasCompletedListOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedListOnboardingKey)
    }

    /// Marks profile photo onboarding as complete.
    func completeProfilePhotoOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedPhotoOnboardingKey)
        self.needsProfilePhoto = false
    }

    /// Marks list creation onboarding as complete.
    func completeListOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedListOnboardingKey)
        self.needsListOnboarding = false
    }

    private let authService = SupabaseAuthService.shared
    private let userService: UserService
    private let locationManager: LocationManager
    private let detailPlaceVM: DetailPlaceViewModel
    
    init(userService: UserService, locationManager: LocationManager, detailPlaceVM: DetailPlaceViewModel) {
        self.userService = userService
        self.locationManager = locationManager
        self.detailPlaceVM = detailPlaceVM
        // Session check is now handled by SplashScreenView for faster startup
    }

    func checkSupabaseSession() async {
        do {
            let session = try await authService.getSession()
            
            // Look up the actual user profile ID instead of using Supabase auth UID
            do {
                let profile = try await userService.fetchUserById(userId: session.user.id.uuidString)
                await MainActor.run {
                    self.isUserLoggedIn = true
                    self.currentUserId = profile.id
                }
                print("✅ Found existing Supabase session: \(profile.id)")
            } catch {
                // Fallback to Supabase auth UID if profile lookup fails
                await MainActor.run {
                    self.isUserLoggedIn = true
                    self.currentUserId = session.user.id.uuidString
                }
                print("✅ Found Supabase session (fallback): \(session.user.id)")
            }
            
            self.registerForFCMToken()
        } catch {
            print("ℹ️ No existing Supabase session: \(error.localizedDescription)")
            await MainActor.run {
                self.isUserLoggedIn = false
                self.profileViewModel = nil
            }
        }
    }
    
    func logout() {
        Task { @MainActor in
            do {
                try await authService.signOut()
                GIDSignIn.sharedInstance.signOut()
                
                // SECURITY: Delegate cache clearing to dedicated service (SRP)
                SessionCleanupService.shared.clearAllSessionData()
                
                isUserLoggedIn = false
                profileViewModel = nil
                currentUserId = nil
                print("👋 User logged out successfully from Supabase")
            } catch {
                print("❌ Error signing out: \(error.localizedDescription)")
            }
        }
    }
    
    func setUserLoggedIn(uid: String) {
        self.isUserLoggedIn = true
        self.currentUserId = uid
        
        // Process any pending push notification token (SRP: delegate to service)
        Task { @MainActor in
            await PushNotificationService.shared.processPendingToken(for: uid)
        }
    }
    
    // MARK: - Push Notifications
    func registerForFCMToken() {
        // TODO: Implement push notifications
        // Options: APNs directly, OneSignal, Pusher Beams, or other service
        print("⚠️ Push notifications need to be implemented")
    }
    
    func signInWithGoogle(user: GIDGoogleUser) {
        Task { @MainActor in
            do {
                guard let idToken = user.idToken?.tokenString else {
                    print("❌ No ID token available")
                    return
                }
                
                // Sign in with Supabase using Google OAuth
                // Note: This requires Google OAuth to be configured in Supabase Dashboard
                _ = try await authService.signInWithIdToken(provider: .google, idToken: idToken)
                
                // Check session after sign-in
                await checkSupabaseSession()
                
                print("✅ Signed in with Google via Supabase")
            } catch {
                print("❌ Supabase Google sign-in error: \(error.localizedDescription)")
            }
        }
    }
}
