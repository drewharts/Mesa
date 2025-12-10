//
//  CustomPlaceCreatorView.swift
//  loc
//
//  Displays "Created by [User]" for custom places.
//  This is a "Dumb Component" - it only displays data passed to it.
//  All data fetching is handled by CustomPlaceCreatorViewModel.
//

import SwiftUI

struct CustomPlaceCreatorView: View {
    
    // MARK: - ViewModel (Smart Component)
    
    @ObservedObject var viewModel: CustomPlaceCreatorViewModel
    
    // MARK: - Optional Navigation Callback
    
    /// Called when user taps on the creator name to navigate to their profile
    var onCreatorTapped: ((String) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let creatorName = viewModel.creatorName {
                creatorBadge(name: creatorName)
            }
            // Show nothing if no creator or hasn't loaded
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)
            
            Text("Loading creator...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func creatorBadge(name: String) -> some View {
        Button(action: handleCreatorTap) {
            HStack(spacing: 6) {
                Image(systemName: "person.fill.badge.plus")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Created by")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(.plain)
        .disabled(onCreatorTapped == nil)
    }
    
    // MARK: - Actions
    
    private func handleCreatorTap() {
        guard let userId = viewModel.creatorUserId else { return }
        onCreatorTapped?(userId)
    }
}

// MARK: - Preview

#Preview("With Creator") {
    let placeService = PlaceService.shared
    let viewModel = CustomPlaceCreatorViewModel(placeService: placeService)
    
    return CustomPlaceCreatorView(
        viewModel: viewModel,
        onCreatorTapped: { userId in
            print("Navigate to user: \(userId)")
        }
    )
    .padding()
}

#Preview("Loading") {
    let placeService = PlaceService.shared
    let viewModel = CustomPlaceCreatorViewModel(placeService: placeService)
    
    return CustomPlaceCreatorView(viewModel: viewModel)
        .padding()
}

