//
//  PlacePhotoCollageViewModel.swift
//  loc
//
//  Single Responsibility: decide a place-photo cover's final layout (2x2 grid vs one photo) once, by
//  validating candidate images before anything is revealed, so covers never flip shape or flash blank.
//

import SwiftUI

@MainActor
final class PlacePhotoCollageViewModel: ObservableObject {
    /// The photos to draw (four = grid, one = single); nil while the layout is still being decided.
    @Published private(set) var resolved: [String]?
    /// True once validation finished and no candidate could be loaded (the cover keeps its generated placeholder).
    @Published private(set) var unresolvable = false

    private let allowsGrid: Bool
    private let frame: CGSize
    private var resolvingKey: [String]?

    /// Creates the resolver and, when every needed image is already in memory, resolves on the first frame.
    init(candidates: [String], allowsGrid: Bool, frame: CGSize) {
        self.allowsGrid = allowsGrid
        self.frame = frame
        resolved = Self.synchronousLayout(candidates: candidates, allowsGrid: allowsGrid, frame: frame)
    }

    /// Re-validates the candidates; a result identical to the current one changes nothing, a different one crossfades in.
    func update(candidates: [String]) async {
        let unique = Self.unique(candidates)
        guard !unique.isEmpty, resolvingKey != unique else { return }
        resolvingKey = unique
        let layout = await resolveLayout(unique)
        guard !Task.isCancelled else { resolvingKey = nil; return }
        guard resolvingKey == unique else { return }
        unresolvable = layout.isEmpty
        publish(layout)
    }

    // MARK: - Resolution

    /// Publishes a layout only when it differs from the current one.
    private func publish(_ layout: [String]) {
        guard !layout.isEmpty, layout != resolved else { return }
        withAnimation(.easeInOut(duration: 0.25)) { resolved = layout }
    }

    /// Returns four loadable photos when a grid is allowed and enough work, else the first loadable photo (empty if none).
    private func resolveLayout(_ candidates: [String]) async -> [String] {
        if allowsGrid, candidates.count >= PlacePhotoCollageLayout.gridCount {
            let size = PlacePhotoCollageLayout.cellSize(forPhotoCount: PlacePhotoCollageLayout.gridCount, frame: frame)
            let grid = await loadable(candidates, need: PlacePhotoCollageLayout.gridCount, size: size)
            if grid.count == PlacePhotoCollageLayout.gridCount { return grid }
        }
        return await loadable(candidates, need: 1, size: frame)
    }

    /// Walks the candidates in order, fetching batches in parallel, until `need` of them load.
    private func loadable(_ candidates: [String], need: Int, size: CGSize) async -> [String] {
        var found: [String] = []
        var index = 0
        while found.count < need, index < candidates.count, !Task.isCancelled {
            let batch = Array(candidates[index..<min(index + need - found.count, candidates.count)])
            index += batch.count
            found += await Self.probe(batch, size: size)
        }
        return found
    }

    /// Fetches the URLs concurrently (filling the image cache) and returns the ones that loaded, in input order.
    private static func probe(_ urls: [String], size: CGSize) async -> [String] {
        let results = await withTaskGroup(of: (Int, Bool).self, returning: Set<Int>.self) { group in
            for (i, url) in urls.enumerated() {
                group.addTask {
                    guard let u = URL(string: url) else { return (i, false) }
                    return (i, await ImageCacheService.shared.fetchImage(for: u, targetSize: size) != nil)
                }
            }
            var ok = Set<Int>()
            for await (i, loaded) in group where loaded { ok.insert(i) }
            return ok
        }
        let failed = urls.indices.filter { !results.contains($0) }.map { urls[$0] }
        failed.forEach { ImageLoadFailureRegistry.shared.markFailed($0) }
        return urls.indices.filter { results.contains($0) }.map { urls[$0] }
    }

    // MARK: - Helpers

    /// Returns the candidates without duplicates, order preserved.
    private static func unique(_ urls: [String]) -> [String] {
        var seen = Set<String>()
        return urls.filter { seen.insert($0).inserted }
    }

    /// Returns the layout when its images are all in the memory cache already, else nil.
    private static func synchronousLayout(candidates: [String], allowsGrid: Bool, frame: CGSize) -> [String]? {
        let urls = unique(candidates)
        func cached(_ list: [String], _ size: CGSize) -> Bool {
            !list.isEmpty && list.allSatisfy { URL(string: $0).flatMap { ImageCacheService.shared.memoryImage(for: $0, targetSize: size) } != nil }
        }
        let n = PlacePhotoCollageLayout.gridCount
        if allowsGrid, urls.count >= n {
            let grid = Array(urls.prefix(n))
            if cached(grid, PlacePhotoCollageLayout.cellSize(forPhotoCount: n, frame: frame)) { return grid }
        }
        guard let first = urls.first, cached([first], frame) else { return nil }
        // A single photo is only final when no grid could be shown for these candidates.
        return allowsGrid && urls.count >= n ? nil : [first]
    }
}
