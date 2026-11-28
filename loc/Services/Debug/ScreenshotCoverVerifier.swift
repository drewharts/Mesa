//
//  ScreenshotCoverVerifier.swift
//  loc
//
//  DEBUG-only: before an Explore screenshot, loads cover photos at the sizes the cards draw so only
//  loadable URLs reach the UI and the image cache is already warm. Read-only; never touches the database.
//

import Foundation
import CoreGraphics

#if DEBUG
enum ScreenshotCoverVerifier {
    /// Returns the candidates that load, in input order, at the given size (fetches run in parallel and fill the cache).
    static func loadable(_ urls: [String], size: CGSize) async -> [String] {
        let ok = await withTaskGroup(of: (Int, Bool).self, returning: Set<Int>.self) { group in
            for (index, string) in urls.enumerated() {
                group.addTask {
                    guard let url = URL(string: string) else { return (index, false) }
                    return (index, await ImageCacheService.shared.fetchImage(for: url, targetSize: size) != nil)
                }
            }
            var found = Set<Int>()
            for await (index, loaded) in group where loaded { found.insert(index) }
            return found
        }
        return urls.indices.filter { ok.contains($0) }.map { urls[$0] }
    }

    /// Returns the photos a collage with `allowsGrid` would draw: all loadable ones (grid sizes verified) or one full-frame photo.
    static func verifiedCover(_ urls: [String], frame: CGSize, allowsGrid: Bool) async -> [String] {
        let distinct = Array(NSOrderedSet(array: urls)) as? [String] ?? urls
        guard allowsGrid else { return await firstLoadable(distinct, frame: frame, limit: 1) }
        let quarter = PlacePhotoCollageLayout.cellSize(forPhotoCount: PlacePhotoCollageLayout.gridCount, frame: frame)
        let grid = await loadable(distinct, size: quarter)
        if grid.count >= PlacePhotoCollageLayout.gridCount { return grid }
        return await firstLoadable(grid, frame: frame, limit: 1)
    }

    /// Returns up to `limit` candidates that load at the full frame size, trying them in small parallel batches.
    static func firstLoadable(_ urls: [String], frame: CGSize, limit: Int) async -> [String] {
        var found: [String] = []
        var index = 0
        while found.count < limit, index < urls.count {
            let batch = Array(urls[index..<min(index + 4, urls.count)])
            index += batch.count
            found += await loadable(batch, size: frame)
        }
        return Array(found.prefix(limit))
    }
}
#endif
