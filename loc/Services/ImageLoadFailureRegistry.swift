//
//  ImageLoadFailureRegistry.swift
//  loc
//
//  Single Responsibility: Remember, for the current app session, which image URLs failed to load
//  so image collages can skip them and fall back to other candidates (e.g. expired Google photo URLs
//  that return 403).
//

import Foundation

@MainActor
final class ImageLoadFailureRegistry: ObservableObject {
    static let shared = ImageLoadFailureRegistry()

    @Published private(set) var failedURLs: Set<String> = []

    private init() {}

    /// Records that the image at the URL could not be loaded.
    func markFailed(_ urlString: String) {
        guard !failedURLs.contains(urlString) else { return }
        failedURLs.insert(urlString)
    }

    /// Returns whether the image at the URL has already failed to load this session.
    func hasFailed(_ urlString: String) -> Bool {
        failedURLs.contains(urlString)
    }
}
