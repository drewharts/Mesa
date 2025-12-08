//
//  CollaboratorBadge.swift
//  loc
//
//  DUMB Component: Visual indicator for shared/collaborative lists
//  Single Responsibility: Display collaboration status badge
//

import SwiftUI

struct CollaboratorBadge: View {
    let collaboratorCount: Int
    var style: BadgeStyle = .compact
    
    enum BadgeStyle {
        case compact   // Just icon + count
        case expanded  // Icon + "Shared" text
        case minimal   // Just icon
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
                .font(.caption2)
            
            switch style {
            case .compact:
            if collaboratorCount > 0 {
                Text("\(collaboratorCount)")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            case .expanded:
                Text(collaboratorCount > 0 ? "Shared (\(collaboratorCount))" : "Shared")
                    .font(.caption2)
                    .fontWeight(.medium)
            case .minimal:
                EmptyView()
            }
        }
        .foregroundColor(.white)
        .padding(.horizontal, style == .minimal ? 4 : 6)
        .padding(.vertical, 3)
        .background(Color.blue.opacity(0.85))
        .clipShape(Capsule())
    }
}

// MARK: - Shared List Indicator

/// A more prominent indicator showing the list is shared
struct SharedListIndicator: View {
    let ownerName: String?
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.caption)
            
            if let ownerName = ownerName {
                Text("Shared by \(ownerName)")
                    .font(.caption)
            } else {
                Text("Shared list")
                    .font(.caption)
            }
        }
        .foregroundColor(.secondary)
    }
}

// MARK: - Previews

#Preview("Badge Styles") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            CollaboratorBadge(collaboratorCount: 0, style: .compact)
            CollaboratorBadge(collaboratorCount: 3, style: .compact)
            CollaboratorBadge(collaboratorCount: 12, style: .compact)
        }
        
        HStack(spacing: 12) {
            CollaboratorBadge(collaboratorCount: 0, style: .expanded)
            CollaboratorBadge(collaboratorCount: 3, style: .expanded)
        }
        
        HStack(spacing: 12) {
        CollaboratorBadge(collaboratorCount: 0, style: .minimal)
        }
        
        Divider()
        
        VStack(alignment: .leading, spacing: 8) {
        SharedListIndicator(ownerName: "Sarah")
        SharedListIndicator(ownerName: nil)
        }
    }
    .padding()
}

#Preview("In List Context") {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text("🍕 NYC Pizza Spots")
                .font(.headline)
            Spacer()
        }
        
        HStack {
            Text("🌮 Taco Tour")
                .font(.headline)
            CollaboratorBadge(collaboratorCount: 3)
            Spacer()
        }
    }
    .padding()
}
