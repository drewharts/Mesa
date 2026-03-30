//
//  TasteProfileViewModel.swift
//  loc
//
//  Manages taste profile data loading and share image generation.
//

import Foundation
import SwiftUI

@MainActor
class TasteProfileViewModel: ObservableObject {
    @Published var entries: [TasteProfileEntry] = []
    @Published var isLoading: Bool = false
    @Published var shareImage: UIImage?

    private let postService = SupabasePostService.shared

    /// Loads the taste profile for the given user.
    func loadProfile(userId: String) async {
        guard !isLoading else { return }
        isLoading = true
        do {
            entries = try await postService.fetchTasteProfile(userId: userId)
        } catch {
            print("[TasteProfileViewModel] Failed to load taste profile: \(error)")
        }
        isLoading = false
    }

    /// Total places across all entries.
    var totalPlaces: Int {
        entries.reduce(0) { $0 + $1.count }
    }

    /// Entries with calculated percentages.
    var entriesWithPercentages: [(entry: TasteProfileEntry, percentage: Double)] {
        let total = Double(totalPlaces)
        guard total > 0 else { return [] }
        return entries.map { ($0, Double($0.count) / total * 100) }
    }

    /// Renders the taste profile card to a UIImage for sharing.
    func generateShareImage(userName: String) {
        let view = TasteProfileCardView(
            userName: userName,
            entries: entriesWithPercentages,
            totalPlaces: totalPlaces
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
    }
}
