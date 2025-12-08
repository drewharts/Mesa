//
//  CollaborationService.swift
//  loc
//
//  Service responsible for ALL collaborator database operations
//  Single Responsibility: CRUD operations for place list collaborators
//

import Foundation

// MARK: - Collaboration Errors

enum CollaborationError: LocalizedError {
    case notAuthenticated
    case notAuthorized
    case userNotFound
    case alreadyCollaborator
    case cannotAddSelf
    case listNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "You must be logged in to manage collaborators"
        case .notAuthorized:
            return "You don't have permission to manage collaborators on this list"
        case .userNotFound:
            return "User not found"
        case .alreadyCollaborator:
            return "This user is already a collaborator on this list"
        case .cannotAddSelf:
            return "You cannot add yourself as a collaborator"
        case .listNotFound:
            return "List not found"
        }
    }
}

// MARK: - CollaborationService

@MainActor
class CollaborationService {
    // MARK: - Singleton
    static let shared = CollaborationService()
    
    // MARK: - Dependencies
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    // MARK: - Fetch Collaborators
    
    /// Fetch all collaborators for a specific list
    func fetchCollaborators(listId: String) async throws -> [LightweightCollaborator] {
        let params = FetchCollaboratorsParams(p_list_id: listId)
        
        do {
            let collaborators: [LightweightCollaborator] = try await supabase.client
                .rpc("get_list_collaborators", params: params)
                .execute()
                .value
            
            print("✅ [CollaborationService] Fetched \(collaborators.count) collaborators for list \(listId)")
            return collaborators
        } catch {
            print("❌ [CollaborationService] Failed to fetch collaborators: \(error)")
            throw error
        }
    }
    
    /// Fetch all lists where user is a collaborator (for showing in their lists)
    func fetchSharedLists(userId: String) async throws -> [SharedListInfo] {
        let params = SharedListsParams(p_user_id: userId)
        
        do {
            let lists: [SharedListInfo] = try await supabase.client
                .rpc("get_user_shared_lists", params: params)
                .execute()
                .value
            
            print("✅ [CollaborationService] Fetched \(lists.count) shared lists for user")
            return lists
        } catch {
            print("❌ [CollaborationService] Failed to fetch shared lists: \(error)")
            throw error
        }
    }
    
    /// Get collaboration info for a specific list
    func getListCollaborationInfo(listId: String, userId: String) async throws -> ListCollaborationInfo? {
        let params = ListInfoParams(p_list_id: listId, p_user_id: userId)
        
        do {
            let results: [ListCollaborationInfo] = try await supabase.client
                .rpc("get_list_with_collaboration_info", params: params)
                .execute()
                .value
            
            return results.first
        } catch {
            print("❌ [CollaborationService] Failed to get list info: \(error)")
            throw error
        }
    }
    
    // MARK: - Add Collaborator
    
    /// Add a user as a collaborator to a list
    func addCollaborator(
        listId: String,
        userId: String,
        role: CollaboratorRole,
        addedBy: String
    ) async throws {
        // Validate: can't add yourself
        guard userId != addedBy else {
            throw CollaborationError.cannotAddSelf
        }
        
        let record = CollaboratorInsertRecord(
            list_id: listId,
            user_id: userId,
            role: role.rawValue,
            added_by: addedBy
        )
        
        do {
            try await supabase.client
                .from("place_list_collaborators")
                .insert(record)
                .execute()
            
            print("✅ [CollaborationService] Added collaborator \(userId) to list \(listId) as \(role.rawValue)")
        } catch {
            // Check for duplicate constraint violation
            if error.localizedDescription.contains("duplicate") ||
               error.localizedDescription.contains("unique") {
                throw CollaborationError.alreadyCollaborator
            }
            print("❌ [CollaborationService] Failed to add collaborator: \(error)")
            throw error
        }
    }
    
    // MARK: - Remove Collaborator
    
    /// Remove a collaborator from a list by collaborator record ID
    func removeCollaborator(collaboratorId: String) async throws {
        do {
            try await supabase.client
                .from("place_list_collaborators")
                .delete()
                .eq("id", value: collaboratorId)
                .execute()
            
            print("✅ [CollaborationService] Removed collaborator \(collaboratorId)")
        } catch {
            print("❌ [CollaborationService] Failed to remove collaborator: \(error)")
            throw error
        }
    }
    
    /// Remove self from a shared list (leave list)
    func leaveList(listId: String, userId: String) async throws {
        do {
            try await supabase.client
                .from("place_list_collaborators")
                .delete()
                .eq("list_id", value: listId)
                .eq("user_id", value: userId)
                .execute()
            
            print("✅ [CollaborationService] User \(userId) left list \(listId)")
        } catch {
            print("❌ [CollaborationService] Failed to leave list: \(error)")
            throw error
        }
    }
    
    // MARK: - Update Role
    
    /// Update a collaborator's role
    func updateRole(collaboratorId: String, newRole: CollaboratorRole) async throws {
        do {
            try await supabase.client
                .from("place_list_collaborators")
                .update(["role": newRole.rawValue])
                .eq("id", value: collaboratorId)
                .execute()
            
            print("✅ [CollaborationService] Updated collaborator \(collaboratorId) role to \(newRole.rawValue)")
        } catch {
            print("❌ [CollaborationService] Failed to update role: \(error)")
            throw error
        }
    }
    
    // MARK: - Permission Checks
    
    /// Check if user can edit a list (is owner or editor collaborator)
    func canUserEditList(listId: String, userId: String) async throws -> Bool {
        // First check if user is owner
        let ownerCheck: [OwnerCheckResult] = try await supabase.client
            .from("place_lists")
            .select("user_id")
            .eq("id", value: listId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        if !ownerCheck.isEmpty {
            return true
        }
        
        // Then check if user is editor collaborator
        let collaboratorCheck: [RoleCheckResult] = try await supabase.client
            .from("place_list_collaborators")
            .select("role")
            .eq("list_id", value: listId)
            .eq("user_id", value: userId)
            .eq("role", value: "editor")
            .execute()
            .value
        
        return !collaboratorCheck.isEmpty
    }
    
    /// Check if user is owner of the list
    func isListOwner(listId: String, userId: String) async throws -> Bool {
        let ownerCheck: [OwnerCheckResult] = try await supabase.client
            .from("place_lists")
            .select("user_id")
            .eq("id", value: listId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return !ownerCheck.isEmpty
    }
    
    /// Check if user is a collaborator on the list
    func isCollaborator(listId: String, userId: String) async throws -> Bool {
        let check: [RoleCheckResult] = try await supabase.client
            .from("place_list_collaborators")
            .select("role")
            .eq("list_id", value: listId)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return !check.isEmpty
    }
    
    /// Get collaborator count for a list
    func getCollaboratorCount(listId: String) async throws -> Int {
        let collaborators: [LightweightCollaborator] = try await supabase.client
            .from("place_list_collaborators")
            .select("id, user_id, role")
            .eq("list_id", value: listId)
            .execute()
            .value
        
        return collaborators.count
    }
}

// MARK: - Private DTOs

private extension CollaborationService {
    struct FetchCollaboratorsParams: Encodable {
        let p_list_id: String
    }
    
    struct SharedListsParams: Encodable {
        let p_user_id: String
    }
    
    struct ListInfoParams: Encodable {
        let p_list_id: String
        let p_user_id: String
    }
    
    struct CollaboratorInsertRecord: Encodable {
        let list_id: String
        let user_id: String
        let role: String
        let added_by: String
    }
    
    struct OwnerCheckResult: Decodable {
        let user_id: String
    }
    
    struct RoleCheckResult: Decodable {
        let role: String
    }
}
