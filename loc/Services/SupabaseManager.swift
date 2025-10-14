//
//  SupabaseManager.swift
//  loc
//
//  Supabase client manager (replacement for FirebaseManager)
//

import Foundation
import Supabase

@MainActor
class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
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
    
    /// Access to the database client
    var database: PostgrestClient {
        client.database
    }
    
    /// Access to the auth client
    var auth: AuthClient {
        client.auth
    }
    
    /// Access to the storage client
    // TODO: Fix StorageClient type issue
    // var storage: StorageClient {
    //     client.storage
    // }
    
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

