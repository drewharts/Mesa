//
//  SupabaseConfig.swift
//  loc
//
//  Configuration for Supabase connection
//

import Foundation

struct SupabaseConfig {
    // IMPORTANT: Replace these with your actual Supabase credentials
    // Get these from: https://app.supabase.com > Your Project > Settings > API
    
    static let supabaseURL = URL(string: "https://posfruqvibklcyfxmdbq.supabase.co")!
    // Example: "https://xxxxxxxxxxxxx.supabase.co"
    
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvc2ZydXF2aWJrbGN5ZnhtZGJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjAyNDUzNDYsImV4cCI6MjA3NTgyMTM0Nn0.irjABUegI-qhjzJs3QLzP0xdkENcQmXxXmqN0fGHLqQ"
    // Example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    
    // SECURITY NOTE:
    // The anon key is safe to use in client-side code when Row-Level Security (RLS) is enabled.
    // Never use the service_role key in client-side code!
    // Consider moving these to an .xcconfig file or environment variables for production.
}

