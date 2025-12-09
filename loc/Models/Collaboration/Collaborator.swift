//
//  Collaborator.swift
//  loc
//
//  Data models for list collaborators
//  Single Responsibility: Data representation for collaborators
//

import Foundation

// MARK: - Full Collaborator Model

struct Collaborator: Codable, Identifiable, Equatable {
    let id: String
    let listId: String
    let userId: String
    let role: CollaboratorRole
    let addedBy: String
    let addedAt: Date
    
    // Populated from JOIN with users table
    let userName: String?
    let profilePhotoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case listId = "list_id"
        case userId = "user_id"
        case role
        case addedBy = "added_by"
        case addedAt = "added_at"
        case userName = "user_name"
        case profilePhotoUrl = "profile_photo_url"
    }
}

// MARK: - Lightweight Collaborator for Display

/// Lightweight version returned by database functions
/// Used for efficient list display without full model overhead
struct LightweightCollaborator: Codable, Identifiable, Equatable {
    let id: String
    let userId: String
    let role: String
    let userName: String?
    let profilePhotoUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case role
        case userName = "user_name"
        case profilePhotoUrl = "profile_photo_url"
    }
    
    // MARK: - Computed Properties
    
    var collaboratorRole: CollaboratorRole {
        CollaboratorRole(rawValue: role) ?? .editor
    }
    
    var displayName: String {
        userName ?? "Unknown User"
    }
}

// MARK: - Shared List Info

/// Information about a list shared with the current user
struct SharedListInfo: Codable, Identifiable {
    let listId: String
    let name: String
    let isPublic: Bool
    let image: String?
    let placeCount: Int
    let city: String?
    let ownerId: String
    let ownerName: String?
    let ownerPhotoUrl: String?
    let userRole: String
    let addedAt: Date?
    let collaboratorPhotos: [String]?
    let collaboratorCount: Int?
    
    var id: String { listId }
    
    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case name
        case isPublic = "is_public"
        case image
        case placeCount = "place_count"
        case city
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case ownerPhotoUrl = "owner_photo_url"
        case userRole = "user_role"
        case addedAt = "added_at"
        case collaboratorPhotos = "collaborator_photos"
        case collaboratorCount = "collaborator_count"
    }
    
    var collaboratorRole: CollaboratorRole {
        CollaboratorRole(rawValue: userRole) ?? .editor
    }
    
    /// Convert to LightweightPlaceList for unified display
    func toLightweightPlaceList() -> LightweightPlaceList {
        return LightweightPlaceList(
            list_id: listId,
            name: name,
            is_public: isPublic,
            image: image,
            created_at: nil,
            updated_at: nil,
            distance_meters: nil,
            place_count: placeCount,
            city: city,
            collaborator_count: collaboratorCount,
            is_shared: true,
            owner_name: ownerName,
            owner_photo_url: ownerPhotoUrl,
            collaborator_photos: collaboratorPhotos
        )
    }
}

// MARK: - Collaborative Owned List Info

/// Information about a list OWNED by the user that has collaborators
/// Used to ensure all collaborative lists appear in Shared filter (not paginated)
struct CollaborativeOwnedList: Codable, Identifiable {
    let listId: String
    let name: String
    let isPublic: Bool
    let image: String?
    let placeCount: Int
    let city: String?
    let collaboratorPhotos: [String]?
    let collaboratorCount: Int
    
    var id: String { listId }
    
    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case name
        case isPublic = "is_public"
        case image
        case placeCount = "place_count"
        case city
        case collaboratorPhotos = "collaborator_photos"
        case collaboratorCount = "collaborator_count"
    }
    
    /// Convert to LightweightPlaceList for unified display
    /// Note: is_shared = false because user OWNS this list (they shared it with others)
    func toLightweightPlaceList() -> LightweightPlaceList {
        return LightweightPlaceList(
            list_id: listId,
            name: name,
            is_public: isPublic,
            image: image,
            created_at: nil,
            updated_at: nil,
            distance_meters: nil,
            place_count: placeCount,
            city: city,
            collaborator_count: collaboratorCount,
            is_shared: false, // User owns this list
            owner_name: nil,  // User is the owner
            owner_photo_url: nil,
            collaborator_photos: collaboratorPhotos
        )
    }
}

// MARK: - List Collaboration Info

/// Collaboration information for a specific list
struct ListCollaborationInfo: Codable {
    let listId: String
    let name: String
    let isPublic: Bool
    let image: String?
    let city: String?
    let ownerId: String
    let ownerName: String?
    let ownerPhotoUrl: String?
    let isOwner: Bool
    let isCollaborator: Bool
    let userRole: String?
    let collaboratorCount: Int
    
    enum CodingKeys: String, CodingKey {
        case listId = "list_id"
        case name
        case isPublic = "is_public"
        case image
        case city
        case ownerId = "owner_id"
        case ownerName = "owner_name"
        case ownerPhotoUrl = "owner_photo_url"
        case isOwner = "is_owner"
        case isCollaborator = "is_collaborator"
        case userRole = "user_role"
        case collaboratorCount = "collaborator_count"
    }
    
    // MARK: - Computed Properties
    
    var canEdit: Bool {
        isOwner || (isCollaborator && userRole == "editor")
    }
    
    var hasCollaborators: Bool {
        collaboratorCount > 0
    }
}

