//
//  SupabaseManager.swift
//  loc
//
//  Supabase client manager for database operations.
//

import Foundation
import Supabase

@MainActor
class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private nonisolated init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfig.supabaseURL,
            supabaseKey: SupabaseConfig.supabaseAnonKey,
            options: SupabaseClientOptions(
                db: SupabaseClientOptions.DatabaseOptions(
                    schema: "public"
                ),
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true
                ),
                global: SupabaseClientOptions.GlobalOptions(
                    headers: ["X-Client-Info": "mesa-ios"]
                )
            )
        )
    }
    
    // MARK: - Convenience accessors
    
    // Note: Removed deprecated 'database' property
    // Use 'client.from("table_name")' directly instead of 'database.from("table_name")'
    
    /// Access to the auth client
    var auth: AuthClient {
        client.auth
    }
    
    /// Debug: Check current authentication status
    func debugAuthStatus() async {
        do {
            _ = try await client.auth.user()
        } catch {
            print("❌ [SupabaseManager] No authenticated user: \(error)")
        }
    }
    
    /// Access to the storage client
    var storage: SupabaseStorageClient {
        client.storage
    }
    
    /// Access to the realtime client (using V2)
    var realtime: RealtimeClientV2 {
        client.realtimeV2
    }
    
    // MARK: - Helper methods
    
    /// Get the current authenticated user ID
    var currentUserId: String? {
        get async {
            try? await auth.session.user.id.uuidString
        }
    }
    
    /// Check if user is authenticated
    var isAuthenticated: Bool {
        get async {
            (try? await auth.session) != nil
        }
    }
}

