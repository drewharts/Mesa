//
//  CreateListTileView.swift
//  loc
//
//  DUMB Component: Displays a "create new list" tile with plus icon
//  Single Responsibility: Render create list UI and trigger callback on tap
//
//  Created by Cursor on 12/28/24.
//

import SwiftUI

/// A tile component that displays a plus icon for creating a new list.
/// Matches the styling of list tiles in the grid layout.
struct CreateListTileView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                plusIconTile
                tileLabel
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Plus Icon Tile
    
    private var plusIconTile: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundColor(.gray.opacity(0.6))
            
            Text("Create List")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [8, 4]))
                .foregroundColor(.gray.opacity(0.3))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - Tile Label
    
    private var tileLabel: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Start organizing")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .lineLimit(1)
            
            Text("Tap to create your first list")
                .font(.caption2)
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    CreateListTileView(onTap: {})
        .frame(width: 160)
        .padding()
}
