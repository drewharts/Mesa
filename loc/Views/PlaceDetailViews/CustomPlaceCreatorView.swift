//
//  CustomPlaceCreatorView.swift
//  loc
//
//  Displays "Created by [profile picture]" for custom places.
//  Shows in the type row of PlaceDetailTabsView.
//  This is a display component - data fetching handled by CustomPlaceCreatorViewModel.
//

import SwiftUI

struct CustomPlaceCreatorView: View {
    
    // MARK: - ViewModel (Smart Component)
    
    @ObservedObject var viewModel: CustomPlaceCreatorViewModel
    
    // MARK: - Navigation Callback
    
    /// Called when user taps to navigate to creator's profile
    var onCreatorTapped: ((String) -> Void)?
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if viewModel.hasCreator {
                creatorBadge
            }
            // Show nothing if no creator or hasn't loaded
        }
    }
    
    // MARK: - Subviews
    
    private var loadingView: some View {
        HStack(spacing: 4) {
            ProgressView()
                .scaleEffect(0.6)
        }
    }
    
    private var creatorBadge: some View {
        Button(action: handleCreatorTap) {
            HStack(spacing: 4) {
                Text("Created by")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                // Profile picture
                profilePicture
            }
        }
        .buttonStyle(.plain)
        .disabled(onCreatorTapped == nil)
    }
    
    @ViewBuilder
    private var profilePicture: some View {
        if let photoUrl = viewModel.creatorPhotoUrl, let url = URL(string: photoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                case .failure, .empty:
                    initialsCircle
                @unknown default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }
    
    private var initialsCircle: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 20, height: 20)
            .overlay(
                Text(viewModel.creatorName?.prefix(1).uppercased() ?? "?")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.gray)
            )
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
