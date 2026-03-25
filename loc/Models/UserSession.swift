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
    @Published var needsPhoneOnboarding: Bool = false
    @Published var needsProfilePhoto: Bool = false
    @Published var needsListOnboarding: Bool = false

    private static let hasCompletedPhoneOnboardingKey = "hasCompletedPhoneOnboarding"
    private static let hasCompletedPhotoOnboardingKey = "hasCompletedProfilePhotoOnboarding"
    private static let hasCompletedListOnboardingKey = "hasCompletedListOnboarding"
    private static let cachedProfileIdKey = "cachedProfileId"

    /// Returns the cached profile ID from a previous session, if available.
    static var cachedProfileId: String? {
        UserDefaults.standard.string(forKey: cachedProfileIdKey)
    }

    /// Persists the profile ID to UserDefaults for faster subsequent launches.
    func cacheProfileId(_ profileId: String) {
        UserDefaults.standard.set(profileId, forKey: Self.cachedProfileIdKey)
    }

    /// Clears the cached profile ID (e.g., on logout).
    static func clearCachedProfileId() {
        UserDefaults.standard.removeObject(forKey: cachedProfileIdKey)
    }

    /// Checks whether the user has completed phone number onboarding.
    static var hasCompletedPhoneOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedPhoneOnboardingKey)
    }

    /// Checks whether the user has completed profile photo onboarding.
    static var hasCompletedPhotoOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedPhotoOnboardingKey)
    }

    /// Checks whether the user has completed list creation onboarding.
    static var hasCompletedListOnboarding: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedListOnboardingKey)
    }

    /// Marks phone number onboarding as complete.
    func completePhoneOnboarding() {
        UserDefaults.standard.set(true, forKey: Self.hasCompletedPhoneOnboardingKey)
        self.needsPhoneOnboarding = false
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

            // Redeem any pending trip invitations on session restore
            if let userId = self.currentUserId {
                Task { @MainActor in
                    await self.redeemPendingTripInvitations(userId: userId)
                }
            }
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

        // Redeem any pending trip invitations (token-based or phone-based)
        Task { @MainActor in
            await redeemPendingTripInvitations(userId: uid)
        }
    }

    // MARK: - Trip Invitation Redemption

    /// Redeems pending trip invitations after login — checks for token-based and phone-based invites.
    private func redeemPendingTripInvitations(userId: String) async {
        let invitationService = await ServiceContainer.shared.tripInvitationService
        await redeemTokenBasedInvitation(service: invitationService, userId: userId)
        await redeemPhoneBasedInvitations(service: invitationService, userId: userId)
    }

    /// Redeems a deep-link invite token stored in UserDefaults before the user logged in.
    private func redeemTokenBasedInvitation(service: TripInvitationService, userId: String) async {
        guard let pendingToken = UserDefaults.standard.string(forKey: "pendingInviteToken") else { return }
        UserDefaults.standard.removeObject(forKey: "pendingInviteToken")
        do {
            let redeemed = try await service.redeemInvitationByToken(userId: userId, token: pendingToken)
            for trip in redeemed {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TripInvitationRedeemed"),
                    object: nil,
                    userInfo: ["tripId": trip.tripId, "tripName": trip.tripName]
                )
            }
        } catch {
            print("❌ [UserSession] Failed to redeem invite token: \(error)")
        }
    }

    /// Looks up the user's phone number and redeems any invitations sent to that number.
    private func redeemPhoneBasedInvitations(service: TripInvitationService, userId: String) async {
        do {
            let profile = try await userService.fetchUserById(userId: userId)
            guard let phone = profile.phoneNumber, !phone.isEmpty else { return }

            let redeemed = try await service.redeemPendingInvitations(userId: userId, phoneNumber: phone)
            for trip in redeemed {
                NotificationCenter.default.post(
                    name: NSNotification.Name("TripInvitationRedeemed"),
                    object: nil,
                    userInfo: ["tripId": trip.tripId, "tripName": trip.tripName]
                )
            }
        } catch {
            print("❌ [UserSession] Failed to redeem phone-based invitations: \(error)")
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
