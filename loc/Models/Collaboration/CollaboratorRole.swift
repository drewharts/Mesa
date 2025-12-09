//
//  CollaboratorRole.swift
//  loc
//
//  Enum defining collaboration permission levels
//  Single Responsibility: Define role types and their display properties
//
//  Note: Currently only 'editor' role exists - all collaborators can edit
//

import Foundation

enum CollaboratorRole: String, Codable, CaseIterable {
    case editor = "editor"
    
    var displayName: String {
        return "Can edit"
    }
    
    var shortName: String {
        return "Editor"
    }
    
    var icon: String {
        return "pencil"
    }
    
    var canEdit: Bool {
        return true
    }
}

