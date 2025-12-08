//
//  CollaboratorRole.swift
//  loc
//
//  Enum defining collaboration permission levels
//  Single Responsibility: Define role types and their display properties
//

import Foundation

enum CollaboratorRole: String, Codable, CaseIterable {
    case viewer = "viewer"
    case editor = "editor"
    
    var displayName: String {
        switch self {
        case .viewer: return "Can view"
        case .editor: return "Can edit"
        }
    }
    
    var shortName: String {
        switch self {
        case .viewer: return "Viewer"
        case .editor: return "Editor"
        }
    }
    
    var icon: String {
        switch self {
        case .viewer: return "eye"
        case .editor: return "pencil"
        }
    }
    
    var canEdit: Bool {
        self == .editor
    }
}

