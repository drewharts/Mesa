//
//  ListHeaderView.swift
//  loc
//
//  DUMB Component: Header for lists section with LISTS label and action buttons
//  Single Responsibility: Display header with title, shared filter, and add list actions
//
//  Layout: [LISTS label] ... [Shared button] [Plus button]
//  Matches FAVORITES and VIDEOS header style
//
//  Accepts state from ViewModel, contains no business logic
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI
import UIKit

struct ListHeaderView: View {
    // MARK: - Parameters (passed from ViewModel via View)
    
    var showOnlyShared: Bool
    var hasSharedLists: Bool
    var isFilterEnabled: Bool = true  // Default enabled for backward compatibility
    var isSearching: Bool = false
    var onToggleFilter: () -> Void
    var onToggleSearch: () -> Void
    var onAddList: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        HStack {
            // Lists label on left (matches Favorites/Videos style)
            Text("Lists")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Action buttons on right
            HStack(spacing: 12) {
                // Shared filter button (only show if there are shared lists OR loading)
                if hasSharedLists || !isFilterEnabled {
                    sharedFilterButton
                }
                
                // Search button
                searchButton
                
                // Add list button (matches ListSelectionSheet style)
            Button(action: onAddList) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color(.systemGray5)))
                        .contentShape(Circle())
                }
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
                if !isFilterEnabled {
                    // Show loading indicator when disabled
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 10))
                }
                Text("Shared")
                    .font(.subheadline)
            }
            .foregroundColor(buttonForegroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(buttonBackgroundColor)
            )
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .disabled(!isFilterEnabled)
    }
    
    // MARK: - Search Button
    
    private var searchButton: some View {
        Button(action: onToggleSearch) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSearching ? .white : .gray)
                .frame(width: 32, height: 32)
                .background(Circle().fill(isSearching ? Color.primary : Color(.systemGray5)))
                .contentShape(Circle())
        }
    }
    
    // MARK: - Computed Colors (SRP: Visual state derived from parameters)
    
    private var buttonForegroundColor: Color {
        if !isFilterEnabled {
            return .secondary
        }
        return showOnlyShared ? .white : .primary
    }
    
    private var buttonBackgroundColor: Color {
        if !isFilterEnabled {
            return Color(.systemGray5)
        }
        return showOnlyShared ? Color.primary : Color(.systemGray5)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        Text("With shared lists").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: true,
            isFilterEnabled: true,
            isSearching: false,
            onToggleFilter: {},
            onToggleSearch: {},
            onAddList: {}
        )
        
        Text("Filter active").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: true,
            hasSharedLists: true,
            isFilterEnabled: true,
            isSearching: false,
            onToggleFilter: {},
            onToggleSearch: {},
            onAddList: {}
        )
        
        Text("Search active").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: true,
            isFilterEnabled: true,
            isSearching: true,
            onToggleFilter: {},
            onToggleSearch: {},
            onAddList: {}
        )
        
        Text("Loading state (disabled)").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: false,
            isFilterEnabled: false,
            isSearching: false,
            onToggleFilter: {},
            onToggleSearch: {},
            onAddList: {}
        )
        
        Text("No shared lists").font(.caption2).foregroundColor(.gray)
        ListHeaderView(
            showOnlyShared: false,
            hasSharedLists: false,
            isFilterEnabled: true,
            isSearching: false,
            onToggleFilter: {},
            onToggleSearch: {},
            onAddList: {}
        )
    }
    .padding()
}
