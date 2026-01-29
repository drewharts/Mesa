//
//  ProfileTikToksView.swift
//  loc
//
//  Displays the TikToks section in the user's profile.
//  Uses shared ProfilePlacesPreviewGrid and ProfileEmptyState components.
//

import SwiftUI

struct ProfileTikToksView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @State private var showingTikToksPopup = false
    @State private var showingHelpSheet = false

    /// Convenience accessor for TikTok view model.
    private var tikTokVM: ProfileTikTokViewModel { profile.tikTokViewModel }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow
            tiktoksCard
            Divider()
                .padding(.horizontal, 20)
        }
        .onAppear {
            profile.refreshTikTokPlacesAfterImport()
        }
        .sheet(isPresented: $showingTikToksPopup) {
            TikToksPopupView()
        }
        .sheet(isPresented: $showingHelpSheet) {
            TikTokImportHelpView()
        }
    }

    // MARK: - Header Row

    private var headerRow: some View {
        HStack {
            Text("TIKTOKS")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Button(action: { showingHelpSheet = true }) {
                Image(systemName: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - TikToks Card

    private var tiktoksCard: some View {
        Button(action: { showingTikToksPopup = true }) {
            Group {
                if tikTokVM.isLoadingTikTokPlaces {
                    loadingState
                } else if tikTokVM.lightweightExternalPlaces.isEmpty {
                    emptyState
                } else {
                    ProfilePlacesPreviewGrid(tiktokPlaces: tikTokVM.lightweightExternalPlaces)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading TikToks...")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
    }

    private var emptyState: some View {
        ProfileEmptyState(
            icon: "video",
            title: "No TikToks yet",
            message: "Add places from TikTok videos to see them here"
        )
    }
}
