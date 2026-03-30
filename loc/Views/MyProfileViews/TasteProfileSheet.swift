//
//  TasteProfileSheet.swift
//  loc
//
//  Sheet showing the user's taste profile with option to share.
//

import SwiftUI

struct TasteProfileSheet: View {
    @StateObject private var viewModel = TasteProfileViewModel()
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Your Taste Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        shareButton
                    }
                }
        }
        .task {
            if let userId = userSession.currentUserId {
                await viewModel.loadProfile(userId: userId)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.entries.isEmpty {
            emptyState
        } else {
            profileCard
        }
    }

    private var profileCard: some View {
        VStack(spacing: 20) {
            TasteProfileCardView(
                userName: profile.user?.firstName ?? "You",
                entries: viewModel.entriesWithPercentages,
                totalPlaces: viewModel.totalPlaces
            )
            .shadow(color: .black.opacity(0.1), radius: 10, y: 5)

            Text("Share your taste with friends!")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Save more places to see your taste profile")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var shareButton: some View {
        Button {
            viewModel.generateShareImage(userName: profile.user?.firstName ?? "You")
            if let image = viewModel.shareImage {
                ServiceContainer.shared.placeShareService.shareImage(image)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.entries.isEmpty)
    }
}
