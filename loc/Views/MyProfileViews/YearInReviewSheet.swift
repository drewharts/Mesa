//
//  YearInReviewSheet.swift
//  loc
//
//  Sheet showing the user's Mesa recap with option to share.
//

import SwiftUI

struct YearInReviewSheet: View {
    @EnvironmentObject var userSession: UserSession
    @EnvironmentObject var profile: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var stats: YearInReviewStats?
    @State private var isLoading = true

    var body: some View {
        NavigationView {
            content
                .navigationTitle("Your Mesa Recap")
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
                do {
                    stats = try await SupabasePostService.shared.fetchYearInReview(userId: userId)
                } catch {
                    print("Failed to load recap: \(error)")
                }
                isLoading = false
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let stats = stats {
            VStack(spacing: 20) {
                YearInReviewCardView(
                    userName: profile.user?.firstName ?? "You",
                    stats: stats
                )
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)

                Text("Share your recap with friends!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Start exploring to build your recap")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var shareButton: some View {
        Button {
            guard let stats = stats else { return }
            let view = YearInReviewCardView(
                userName: profile.user?.firstName ?? "You",
                stats: stats
            )
            let renderer = ImageRenderer(content: view)
            renderer.scale = 3.0
            if let image = renderer.uiImage {
                ServiceContainer.shared.placeShareService.shareImage(image)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(stats == nil)
    }
}
