//
//  PlacesCountBadgeView.swift
//  loc
//
//  DUMB Component: Displays a places count badge on profile pictures
//  Single Responsibility: Show count badge with tap-to-explain interaction
//
//  Usage: Overlay on profile pictures to show total places count
//

import SwiftUI

struct PlacesCountBadgeView: View {
    let count: Int
    let userName: String
    let isOwnProfile: Bool
    
    @State private var showExplanation: Bool = false
    
    // MARK: - Constants
    
    private let badgeSize: CGFloat = 28
    private let fontSize: CGFloat = 12
    
    // MARK: - Computed Properties
    
    private var displayCount: String {
        if count >= 1000 {
            return "\(count / 1000)k+"
        }
        return "\(count)"
    }
    
    private var explanationText: String {
        if isOwnProfile {
            return "You have interacted with \(count) unique places — saved, reviewed, or created."
        } else {
            return "\(userName) has interacted with \(count) unique places — saved, reviewed, or created."
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: {
            showExplanation = true
        }) {
            ZStack {
                // Badge background - gradient for visual interest
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.orange, Color.pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: badgeSize, height: badgeSize)
                
                // White border
                Circle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: badgeSize, height: badgeSize)
                
                // Count text
                Text(displayCount)
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .alert("Places Count", isPresented: $showExplanation) {
            Button("Got it!", role: .cancel) { }
        } message: {
            Text(explanationText)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        // Example: on profile picture
        ZStack(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 100, height: 100)
                .overlay(
                    Image(systemName: "person.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                )
            
            PlacesCountBadgeView(
                count: 47,
                userName: "John",
                isOwnProfile: false
            )
            .offset(x: 4, y: 4)
        }
        
        // Different count displays
        HStack(spacing: 20) {
            PlacesCountBadgeView(count: 5, userName: "Test", isOwnProfile: true)
            PlacesCountBadgeView(count: 47, userName: "Test", isOwnProfile: true)
            PlacesCountBadgeView(count: 123, userName: "Test", isOwnProfile: true)
            PlacesCountBadgeView(count: 1500, userName: "Test", isOwnProfile: true)
        }
    }
    .padding()
}


