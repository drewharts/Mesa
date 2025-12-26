//
//  PushNotificationService.swift
//  loc
//
//  Service for managing push notification device tokens.
//  Single Responsibility: Handles all push notification token management concerns.
//  Follows MVVM: Service layer handles business logic, ViewModels coordinate, Views display.
//

import Foundation

/// Service responsible for managing APNs device token registration and storage.
/// Handles token conversion, storage, and pending token management when user is not logged in.
@MainActor
class PushNotificationService {
    // MARK: - Singleton
    
    static let shared = PushNotificationService()
    
    // MARK: - Dependencies
    
    private let authService: SupabaseAuthService
    private let userService: UserService
    
    // MARK: - Constants
    
    private let pendingTokenKey = "pending_apns_token"
    
    // MARK: - Initialization
    
    private init(
        authService: SupabaseAuthService = SupabaseAuthService.shared,
        userService: UserService = UserService.shared
    ) {
        self.authService = authService
        self.userService = userService
    }
    
    // MARK: - Device Token Management
    
    /// Converts APNs device token Data to hex string format
    func convertDeviceToken(_ deviceToken: Data) -> String {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        return tokenParts.joined()
    }
    
    /// Handles device token received from APNs
    /// - Parameter deviceToken: The raw device token Data from APNs
    func handleDeviceTokenReceived(_ deviceToken: Data) {
        let tokenString = convertDeviceToken(deviceToken)
        print("📱 [PushNotification] Device token received: \(tokenString)")
        
        Task { @MainActor in
            await storeDeviceToken(tokenString)
        }
    }
    
    /// Stores device token for current user, or saves as pending if no user logged in
    /// - Parameter tokenString: The device token as hex string
    func storeDeviceToken(_ tokenString: String) async {
        guard let userId = await getCurrentUserId() else {
            print("⚠️ [PushNotification] No user ID available, saving token as pending")
            savePendingToken(tokenString)
            return
        }
        
        await saveTokenForUser(userId: userId, token: tokenString)
    }
    
    /// Saves pending token to be stored when user logs in
    /// - Parameter token: The device token string
    private func savePendingToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: pendingTokenKey)
    }
    
    /// Clears any pending token
    func clearPendingToken() {
        UserDefaults.standard.removeObject(forKey: pendingTokenKey)
    }
    
    /// Retrieves and stores any pending token for the logged-in user
    /// Should be called after user login
    /// - Parameter userId: The user ID to associate the token with
    func processPendingToken(for userId: String) async {
        guard let pendingToken = UserDefaults.standard.string(forKey: pendingTokenKey) else {
            return
        }
        
        print("📱 [PushNotification] Processing pending token for user: \(userId)")
        await saveTokenForUser(userId: userId, token: pendingToken)
        clearPendingToken()
    }
    
    // MARK: - Private Helpers
    
    /// Gets current user ID from auth service
    private func getCurrentUserId() async -> String? {
        // Try synchronous access first
        if let userId = authService.currentUserId {
            return userId
        }
        
        // Fall back to async session check
        do {
            let session = try await authService.getSession()
            return session.user.id.uuidString
        } catch {
            print("⚠️ [PushNotification] Could not get user ID: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Saves device token to Supabase for the given user
    /// - Parameters:
    ///   - userId: The user ID
    ///   - token: The device token string
    private func saveTokenForUser(userId: String, token: String) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            userService.updateFCMToken(userId: userId, token: token) { error in
                if let error = error {
                    print("❌ [PushNotification] Failed to store device token: \(error.localizedDescription)")
                } else {
                    print("✅ [PushNotification] Device token stored successfully for user \(userId)")
                }
                continuation.resume()
            }
        }
    }
}

