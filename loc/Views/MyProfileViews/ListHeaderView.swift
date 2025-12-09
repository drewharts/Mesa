//
//  ListHeaderView.swift
//  loc
//
//  DUMB Component: Header for lists section with filter and add buttons
//  Single Responsibility: Display header with shared filter and add list actions
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI
import UIKit

struct ListHeaderView: View {
    var showOnlyShared: Bool
    var hasSharedLists: Bool
    var onToggleFilter: () -> Void
    var onAddList: () -> Void
    
    var body: some View {
        HStack {
            // Shared filter on left (only show if there are shared lists)
            if hasSharedLists {
                sharedFilterButton
            }
            
            Spacer()
            
            // Add list button (matches ListSelectionSheet style)
            Button(action: onAddList) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color(.systemGray5)))
            }
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Shared Filter Button
    
    private var sharedFilterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onToggleFilter()
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 10))
                Text("Shared")
                    .font(.subheadline)
            }
            .foregroundColor(showOnlyShared ? .white : .primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(showOnlyShared ? Color.primary : Color(.systemGray5))
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("With shared lists").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: true,
            onToggleFilter: {},
            onAddList: {}
        )
        
        Text("Filter active").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: true,
            hasSharedLists: true,
            onToggleFilter: {},
            onAddList: {}
        )
        
        Text("No shared lists").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: false,
            onToggleFilter: {},
            onAddList: {}
        )
    }
    .padding()
}
