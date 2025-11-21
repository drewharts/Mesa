//
//  AdminService.swift
//  loc
//
//  Admin service for debugging and testing
//  Allows logging in as any user from the database
//

import Foundation
import Supabase

@MainActor
class AdminService: ObservableObject {
    static let shared = AdminService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseURL = SupabaseConfig.supabaseURL
    private var adminClient: SupabaseClient?
    
    private init() {
        #if DEBUG
        if AdminConfig.adminModeEnabled && !AdminConfig.serviceRoleKey.isEmpty && AdminConfig.serviceRoleKey != "YOUR_SERVICE_ROLE_KEY_HERE" {
            // Create a separate client with service_role key for admin operations
            adminClient = SupabaseClient(
                supabaseURL: supabaseURL,
                supabaseKey: AdminConfig.serviceRoleKey
            )
            print("🔧 [AdminService] Admin mode enabled")
        }
        #endif
    }
    
    // MARK: - Fetch All Users
    
    /// Fetch all users from the database
    func fetchAllUsers() async throws -> [AdminUser] {
        guard let adminClient = adminClient else {
            throw NSError(domain: "AdminService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Admin mode not enabled. Please set your service_role key in AdminConfig.swift"
            ])
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Fetch all users from public.users table with explicit field selection
            let response: [AdminUser] = try await adminClient
                .from("users")
                .select("id, email, first_name, last_name, full_name, profile_photo_url, created_at")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ [AdminService] Fetched \(response.count) users from public.users table")
            
            // Debug: Print first user's data to verify fields
            if let firstUser = response.first {
                print("🔍 [AdminService] Sample user data:")
                print("   - ID: \(firstUser.id)")
                print("   - Email: \(firstUser.email ?? "nil")")
                print("   - Name: \(firstUser.fullName ?? "nil") (first: \(firstUser.firstName ?? "nil"), last: \(firstUser.lastName ?? "nil"))")
                print("   - Photo: \(firstUser.profilePhotoUrl ?? "nil")")
            }
            
            return response
            
        } catch {
            let message = "Failed to fetch users: \(error.localizedDescription)"
            errorMessage = message
            print("❌ [AdminService] \(message)")
            throw error
        }
    }
    
    // MARK: - Login As User
    
    /// Login as a specific user by their ID
    /// Uses admin service_role key to generate auth tokens directly (no password change)
    func loginAsUser(_ user: AdminUser) async throws {
        guard let adminClient = adminClient else {
            throw NSError(domain: "AdminService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Admin mode not enabled"
            ])
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            // Sign out current user first
            try await SupabaseAuthService.shared.signOut()
            
            // Look up auth user by email (not ID, since IDs may differ for migrated users)
            print("🔍 [AdminService] Logging in as user from public.users:")
            print("   - public.users.id: \(user.id)")
            print("   - email: \(user.email ?? "nil")")
            
            // Get email from the user object (from public.users)
            guard let userEmail = user.email, !userEmail.isEmpty else {
                throw NSError(domain: "AdminService", code: -5, userInfo: [
                    NSLocalizedDescriptionKey: "User has no email - cannot lookup in auth.users"
                ])
            }
            
            // Find auth user by email
            let getUserURL = supabaseURL.appendingPathComponent("auth/v1/admin/users")
            var components = URLComponents(url: getUserURL, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "email", value: userEmail)]
            
            var getUserRequest = URLRequest(url: components.url!)
            getUserRequest.httpMethod = "GET"
            getUserRequest.setValue("Bearer \(AdminConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
            getUserRequest.setValue(AdminConfig.serviceRoleKey, forHTTPHeaderField: "apikey")
            
            let (userData, userResponse) = try await URLSession.shared.data(for: getUserRequest)
            
            guard let httpResponse = userResponse as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw NSError(domain: "AdminService", code: -6, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to lookup user in auth.users by email"
                ])
            }
            
            // Parse response - should be an array of users
            guard let authUsersJson = try? JSONSerialization.jsonObject(with: userData) as? [String: Any],
                  let users = authUsersJson["users"] as? [[String: Any]],
                  let authUser = users.first,
                  let authEmail = authUser["email"] as? String else {
                throw NSError(domain: "AdminService", code: -7, userInfo: [
                    NSLocalizedDescriptionKey: "User not found in auth.users - this user may not have authentication enabled"
                ])
            }
            
            print("🔍 [AdminService] Found auth user by email: \(authEmail)")
            
            // Simpler approach: Set a temporary password and sign in
            let tempPassword = "AdminTemp\(UUID().uuidString)"
            
            print("🔍 [AdminService] Setting temporary password...")
            
            // Update user's password using admin API
            let updateURL = supabaseURL.appendingPathComponent("auth/v1/admin/users/\(user.id)")
            var updateRequest = URLRequest(url: updateURL)
            updateRequest.httpMethod = "PUT"
            updateRequest.setValue("Bearer \(AdminConfig.serviceRoleKey)", forHTTPHeaderField: "Authorization")
            updateRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            updateRequest.setValue(AdminConfig.serviceRoleKey, forHTTPHeaderField: "apikey")
            
            let updateBody: [String: Any] = [
                "password": tempPassword
            ]
            updateRequest.httpBody = try JSONSerialization.data(withJSONObject: updateBody)
            
            let (updateData, updateResponse) = try await URLSession.shared.data(for: updateRequest)
            
            guard let updateHttpResponse = updateResponse as? HTTPURLResponse,
                  (200...299).contains(updateHttpResponse.statusCode) else {
                let errorMsg = String(data: updateData, encoding: .utf8) ?? "Unknown error"
                throw NSError(domain: "AdminService", code: -3, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to set temporary password: \(errorMsg)"
                ])
            }
            
            print("🔍 [AdminService] Password set, signing in...")
            
            // Now sign in with email and temporary password
            let session = try await SupabaseManager.shared.auth.signIn(
                email: authEmail,
                password: tempPassword
            )
            
            print("✅ [AdminService] Successfully logged in as user: \(user.displayName)")
            
        } catch {
            let message = "Failed to login as user: \(error.localizedDescription)"
            errorMessage = message
            print("❌ [AdminService] \(message)")
            throw error
        }
    }
    
    // MARK: - Search Users
    
    /// Search users by name or email
    func searchUsers(query: String) async throws -> [AdminUser] {
        guard let adminClient = adminClient else {
            throw NSError(domain: "AdminService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Admin mode not enabled"
            ])
        }
        
        guard !query.isEmpty else {
            return try await fetchAllUsers()
        }
        
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            let lowerQuery = query.lowercased()
            
            // Search by name or email
            let response: [AdminUser] = try await adminClient
                .from("users")
                .select("id, email, first_name, last_name, full_name, profile_photo_url, created_at")
                .or("full_name_lower.ilike.%\(lowerQuery)%,email.ilike.%\(lowerQuery)%")
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ [AdminService] Found \(response.count) users matching '\(query)'")
            return response
            
        } catch {
            let message = "Failed to search users: \(error.localizedDescription)"
            errorMessage = message
            print("❌ [AdminService] \(message)")
            throw error
        }
    }
}

// MARK: - Admin User Model

struct AdminUser: Codable, Identifiable {
    let id: String
    let email: String?  // Optional - some users may not have email
    let firstName: String?
    let lastName: String?
    let fullName: String?
    let profilePhotoUrl: String?
    let createdAt: Date?
    
    var displayName: String {
        if let fullName = fullName, !fullName.isEmpty {
            return fullName
        }
        if let firstName = firstName, let lastName = lastName {
            return "\(firstName) \(lastName)"
        }
        if let email = email, !email.isEmpty {
            return email
        }
        return "User \(id.prefix(8))"  // Fallback to showing partial ID
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case firstName = "first_name"
        case lastName = "last_name"
        case fullName = "full_name"
        case profilePhotoUrl = "profile_photo_url"
        case createdAt = "created_at"
    }
}

