//
//  AdminConfig.swift
//  loc
//
//  Admin configuration for debug/development purposes
//  ⚠️ NEVER include service_role key in production builds
//

import Foundation

struct AdminConfig {
    #if DEBUG
    // 🔐 SERVICE ROLE KEY - ONLY FOR DEBUG BUILDS
    // Get this from: Supabase Dashboard > Project Settings > API > service_role key
    // ⚠️ This key has FULL database access - keep it secret!
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBvc2ZydXF2aWJrbGN5ZnhtZGJxIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MDI0NTM0NiwiZXhwIjoyMDc1ODIxMzQ2fQ.DfOt_3xvYwe2TTPJ2LlIHFCZf3HPNNbeOf2oHWkJ5vg"
    
    // Set to true to enable admin features
    static let adminModeEnabled = true
    #else
    static let serviceRoleKey = ""
    static let adminModeEnabled = false
    #endif
}

