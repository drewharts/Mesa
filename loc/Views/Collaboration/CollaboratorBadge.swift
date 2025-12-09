//
//  CollaboratorBadge.swift
//  loc
//
//  DUMB Component: Visual badge showing collaborator count
//  Single Responsibility: Display a compact collaboration indicator badge
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

// MARK: - Preview

#Preview {
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
        
        CollaboratorBadge(collaboratorCount: 0, style: .minimal)
    }
    .padding()
}
