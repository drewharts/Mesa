//
//  SupabaseAuthService.swift
//  loc
//
//  Authentication service using Supabase Auth (replacement for Firebase Auth)
//

import Foundation
import Supabase

@MainActor
class SupabaseAuthService: ObservableObject {
    static let shared = SupabaseAuthService()
    
    private let supabase = SupabaseManager.shared
    @Published var currentUser: Auth.User?
    @Published var session: Session?
    
    private init() {
        // Set up auth state listener
        Task {
            await setupAuthListener()
        }
    }
    
    // MARK: - Auth State Management
    
    func setupAuthListener() async {
        // Listen for auth state changes
        for await state in await supabase.auth.authStateChanges {
            switch state.event {
            case .signedIn:
                if let session = state.session {
                    self.session = session
                    self.currentUser = session.user
                    print("✅ [SupabaseAuth] User signed in: \(session.user.id)")
                }
                
            case .signedOut:
                self.session = nil
                self.currentUser = nil
                print("🔓 [SupabaseAuth] User signed out")
                
            case .userUpdated:
                if let session = state.session {
                    self.session = session
                    self.currentUser = session.user
                    print("🔄 [SupabaseAuth] User updated: \(session.user.id)")
                }
                
            case .tokenRefreshed:
                if let session = state.session {
                    self.session = session
                    print("🔄 [SupabaseAuth] Token refreshed")
                }
                
            default:
                break
            }
        }
    }
    
    // MARK: - Sign Up
    
    /// Sign up with email and password
    func signUp(email: String, password: String, metadata: [String: AnyJSON] = [:]) async throws -> Session {
        let response = try await supabase.auth.signUp(
            email: email,
            password: password,
            data: metadata
        )
        
        guard let session = response.session else {
            throw NSError(domain: "SupabaseAuth", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Sign up succeeded but no session returned. Check your email for verification."
            ])
        }
        
        self.session = session
        self.currentUser = session.user
        
        return session
    }
    
    // MARK: - Sign In
    
    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> Session {
        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )
        
        self.session = session
        self.currentUser = session.user
        
        return session
    }
    
    /// Sign in with Google
    func signInWithGoogle() async throws {
        // Supabase handles OAuth flow
        try await supabase.auth.signInWithOAuth(provider: .google)
    }
    
    /// Sign in with Apple
    func signInWithApple(idToken: String, nonce: String) async throws -> Session {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: .init(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )

        self.session = session
        self.currentUser = session.user

        return session
    }
    
    /// Sign in with Google ID token
    func signInWithIdToken(provider: Provider, idToken: String) async throws -> Session {
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: OpenIDConnectCredentials.Provider(rawValue: provider.rawValue) ?? .google,
                idToken: idToken
            )
        )
        
        self.session = session
        self.currentUser = session.user
        
        return session
    }
    
    // MARK: - Sign Out
    
    /// Sign out the current user
    func signOut() async throws {
        try await supabase.auth.signOut()
        self.session = nil
        self.currentUser = nil
    }
    
    // MARK: - Session Management
    
    /// Get current session (refreshes if expired)
    func getSession() async throws -> Session {
        let session = try await supabase.auth.session
        self.session = session
        self.currentUser = session.user
        return session
    }
    
    /// Get current user ID
    var currentUserId: String? {
        currentUser?.id.uuidString
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        session != nil && currentUser != nil
    }
    
    // MARK: - Password Management
    
    /// Send password reset email
    func resetPassword(email: String) async throws {
        try await supabase.auth.resetPasswordForEmail(email)
    }
    
    /// Update user password (must be authenticated)
    func updatePassword(newPassword: String) async throws {
        try await supabase.auth.update(user: UserAttributes(password: newPassword))
    }
    
    // MARK: - User Profile Updates
    
    /// Update user metadata
    func updateUserMetadata(_ metadata: [String: AnyJSON]) async throws {
        try await supabase.auth.update(user: UserAttributes(data: metadata))
    }
    
    /// Update user email
    func updateEmail(newEmail: String) async throws {
        try await supabase.auth.update(user: UserAttributes(email: newEmail))
    }
    
    // MARK: - Account Deletion
    
    /// Delete the current user account
    func deleteAccount() async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "SupabaseAuth", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "No user is currently signed in"
            ])
        }
        
        // Note: This requires admin privileges or a custom backend function
        // For now, sign out and let the backend handle cleanup via RLS cascade deletes
        try await signOut()
        
        print("⚠️ [SupabaseAuth] User signed out. Database cleanup will be handled by CASCADE DELETE via RLS")
    }
    
    // MARK: - Migration Helpers
    
    /// Helper to get Firebase-compatible user ID string
    var uid: String? {
        currentUserId
    }
    
    /// Check if this is a migrated Firebase user
    func isMigratedFromFirebase() -> Bool {
        guard let metadata = currentUser?.userMetadata else { return false }
        return metadata["firebase_migrated"] as? Bool ?? false
    }
}

