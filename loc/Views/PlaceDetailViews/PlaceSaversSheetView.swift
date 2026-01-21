//
//  PlaceSaversSheetView.swift
//  loc
//
//  Smart View for displaying all users who saved a place
//  Uses PlaceSaversViewModel - no business logic in view
//

import SwiftUI

struct PlaceSaversSheetView: View {
    // MARK: - Primary ViewModel
    @ObservedObject var viewModel: PlaceSaversViewModel
    
    let placeName: String
    
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                headerSection

                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.error {
                    errorView(error)
                } else if viewModel.totalGlobalSaveCount == 0 {
                    emptyStateView
                } else {
                    saversList
                }
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved by")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(viewModel.totalGlobalSaveCount) \(viewModel.totalGlobalSaveCount == 1 ? "person" : "people")")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Loading
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Error
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Unable to load savers")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.gray)
            Text("No one has saved this place yet")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Savers List
    private var saversList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Current user row (if they saved)
                if viewModel.currentUserSaved {
                    currentUserRow
                    Divider()
                        .padding(.leading, 70)
                }

                // Friends section (followed users)
                if viewModel.hasFollowedSavers {
                    sectionHeader("Friends")

                    ForEach(viewModel.displayableFollowedSavers, id: \.id) { user in
                        SaverRowView(
                            user: user,
                            onTap: {
                                viewModel.selectUser(user, dismiss: { dismiss() })
                            }
                        )

                        Divider()
                            .padding(.leading, 70)
                    }
                }

                // Others section (unfollowed users)
                if viewModel.hasUnfollowedSavers {
                    sectionHeader("Others")

                    ForEach(viewModel.displayableUnfollowedSavers, id: \.id) { user in
                        SaverRowView(
                            user: user,
                            onTap: {
                                viewModel.selectUser(user, dismiss: { dismiss() })
                            }
                        )

                        if user.id != viewModel.displayableUnfollowedSavers.last?.id {
                            Divider()
                                .padding(.leading, 70)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Section Header
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }
    
    // MARK: - Current User Row
    private var currentUserRow: some View {
        HStack(spacing: 12) {
            // Profile image
            if let photoURL = profile.user?.profilePhotoURL {
                AsyncImage(url: photoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure, .empty:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                placeholderImage
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.user?.fullName ?? "You")
                    .font(.body)
                    .fontWeight(.medium)
                
                Text("You")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
    }
    
    private var placeholderImage: some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: 50, height: 50)
            .overlay(
                Text(profile.user?.fullName.prefix(1) ?? "?")
                    .font(.headline)
                    .foregroundColor(.gray)
            )
    }
}

