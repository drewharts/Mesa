//
//  SuggestedProfilesPopupView.swift
//  loc
//
//  Single Responsibility: Display the suggested profiles popup with navigation.
//  Shows a list of preset profiles for new users to explore.
//

import SwiftUI

struct SuggestedProfilesPopupView: View {
    @StateObject private var viewModel = SuggestedProfilesViewModel()
    @Binding var isPresented: Bool

    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.loadError != nil {
                    errorView
                } else {
                    profileListView
                }
            }
            .navigationTitle("Suggested Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        viewModel.markPopupAsSeen()
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
            .navigationDestination(for: ProfileData.self) { profile in
                ExternalUserProfileViewWrapper(user: profile)
            }
        }
        .task {
            await viewModel.loadSuggestedProfiles()
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading profiles...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var errorView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("Unable to load profiles")
                .font(.headline)
            Text("Please check your connection and try again.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await viewModel.retry()
                }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var profileListView: some View {
        VStack(spacing: 0) {
            Text("Check out these profiles to get started!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.bottom, 16)

            Divider()

            ForEach(viewModel.suggestedProfiles) { profile in
                SuggestedProfileRowView(profile: profile) {
                    navigationPath.append(profile)
                }
                .padding(.horizontal, 16)

                if profile.id != viewModel.suggestedProfiles.last?.id {
                    Divider()
                        .padding(.leading, 76)
                }
            }

            Divider()

            Spacer()

            searchHintView
        }
    }

    private var searchHintView: some View {
        VStack(spacing: 8) {
            Divider()

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))

                Text("Use the search bar to find more profiles")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    SuggestedProfilesPopupView(isPresented: .constant(true))
}
