//
//  PlaceActionButton.swift
//  loc
//
//  Created by Cursor Assistant on [current date]
//

import SwiftUI

struct PlaceActionButton: View {
    let place: DetailPlace
    let onAddToList: (() -> Void)?
    let onAddReview: (() -> Void)?
    
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var serviceContainer: ServiceContainer
    
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var selectedAction: ActionType?
    
    private let buttonSize: CGFloat = 40
    private let expandedSize: CGFloat = 200
    private let animationDuration: Double = 0.2
    
    init(place: DetailPlace, onAddToList: (() -> Void)? = nil, onAddReview: (() -> Void)? = nil) {
        self.place = place
        self.onAddToList = onAddToList
        self.onAddReview = onAddReview
    }
    
    enum ActionType: CaseIterable {
        case favorite, share, addToList, addReview

        var icon: String {
            switch self {
            case .favorite: return "star"
            case .share: return "square.and.arrow.up"
            case .addToList: return "bookmark"
            case .addReview: return "plus"
            }
        }

        func iconName(isFavorited: Bool, isInList: Bool) -> String {
            switch self {
            case .favorite: return isFavorited ? "star.fill" : "star"
            case .share: return "square.and.arrow.up"
            case .addToList: return isInList ? "bookmark.fill" : "bookmark"
            case .addReview: return "plus"
            }
        }

        var color: Color {
            switch self {
            case .favorite: return .gray
            case .share: return .gray
            case .addToList: return .gray
            case .addReview: return .gray
            }
        }

        func iconColor(isFavorited: Bool, isInList: Bool, isSelected: Bool) -> Color {
            switch self {
            case .favorite: return isFavorited ? .yellow : .gray
            case .share: return .gray
            case .addToList: return isInList ? .blue : .gray
            case .addReview: return .gray
            }
        }

        var title: String {
            switch self {
            case .favorite: return "Favorite"
            case .share: return "Share"
            case .addToList: return "Add to List"
            case .addReview: return "Add Review"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background that prevents sheet dragging when menu is expanded
            if isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
            }
            
            // Main button and expanded menu
            VStack {
                HStack {
                    Spacer()
                    
                    ZStack {
                        // Expanded menu
                        if isExpanded {
                            VStack(spacing: 8) {
                                ForEach(Array(ActionType.allCases.enumerated()), id: \.offset) { index, action in
                                    ActionButton(
                                        action: action,
                                        isSelected: selectedAction == action,
                                        onTap: {
                                            performAction(action)
                                            collapseMenu()
                                        },
                                        isFavorited: action == .favorite ? profile.isPlaceFavorite(placeId: place.id.uuidString) : false,
                                        isInList: action == .addToList ? profile.isPlaceInAnyList(placeId: place.id.uuidString) : false
                                    )
                                }
                            }
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(radius: 8)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Main button - only show when not expanded
                        if !isExpanded {
                            Button(action: {
                                // Single tap does nothing - only long press expands
                            }) {
                                ThreeDotsTriangle()
                                    .frame(width: buttonSize, height: buttonSize)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                            .simultaneousGesture(
                                LongPressGesture(minimumDuration: 0.3)
                                    .onEnded { _ in
                                        expandMenu()
                                    }
                            )
                        }
                    }
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if isExpanded {
                                    handleDrag(value)
                                }
                            }
                            .onEnded { _ in
                                if isExpanded {
                                    handleDragEnd()
                                }
                            }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }
    
    // MARK: - Helper Methods
    
    private func getMainButtonIcon() -> String {
        return "arrow.up"
    }
    
    private func getMainButtonColor() -> Color {
        return .gray
    }
    
    private func expandMenu() {
        isExpanded = true
    }
    
    private func collapseMenu() {
        isExpanded = false
        selectedAction = nil
        dragOffset = 0
    }
    
    private func handleDrag(_ value: DragGesture.Value) {
        let location = value.location
        
        // Simple calculation: each button is 44 points + 8 points spacing
        let itemHeight: CGFloat = 44
        let spacing: CGFloat = 8
        let totalItemHeight = itemHeight + spacing
        
        // Calculate which item the finger is over
        let itemIndex = Int(location.y / totalItemHeight)
        
        if itemIndex >= 0 && itemIndex < ActionType.allCases.count {
            selectedAction = ActionType.allCases[itemIndex]
        } else {
            selectedAction = nil
        }
    }
    
    private func handleDragEnd() {
        if let action = selectedAction {
            performAction(action)
        }
        collapseMenu()
    }
    
    private func performAction(_ action: ActionType) {
        switch action {
        case .favorite:
            if profile.isPlaceFavorite(placeId: place.id.uuidString) {
                profile.removeFavoritePlace(place: place)
            } else {
                profile.addFavoritePlace(place: place)
            }
            
        case .share:
            serviceContainer.placeShareService.sharePlace(place)
            
        case .addToList:
            onAddToList?()
            
        case .addReview:
            onAddReview?()
        }
    }
}

// MARK: - Action Button Component

struct ActionButton: View {
    let action: PlaceActionButton.ActionType
    let isSelected: Bool
    let onTap: () -> Void
    let isFavorited: Bool
    let isInList: Bool

    var body: some View {
        Button(action: onTap) {
            let iconName = action.iconName(isFavorited: isFavorited, isInList: isInList)
            let iconColor = action.iconColor(isFavorited: isFavorited, isInList: isInList, isSelected: isSelected)

            Image(systemName: iconName)
                .font(.title3)
                .foregroundColor(isSelected ? .white : iconColor)
                .frame(width: isSelected ? 36 : 44, height: isSelected ? 36 : 44)
                .background(isSelected ? iconColor : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Three Dots Triangle Component

struct ThreeDotsTriangle: View {
    var body: some View {
        ZStack {
            // Top dot
            Circle()
                .fill(Color.gray)
                .frame(width: 4, height: 4)
                .offset(y: -4)
            
            // Bottom left dot
            Circle()
                .fill(Color.gray)
                .frame(width: 4, height: 4)
                .offset(x: -3, y: 4)
            
            // Bottom right dot
            Circle()
                .fill(Color.gray)
                .frame(width: 4, height: 4)
                .offset(x: 3, y: 4)
        }
    }
} 