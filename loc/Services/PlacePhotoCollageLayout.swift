//
//  PlacePhotoCollageLayout.swift
//  loc
//
//  Single Responsibility: decide which candidate photos a place-photo collage shows and at what
//  cell size, so the view and the image prefetcher request exactly the same cache entries.
//

import CoreGraphics

enum PlacePhotoCollageLayout {
    static let gridCount = 4

    /// The photos to draw: the first four candidates that have not failed (a 2x2 grid), else just the first healthy one.
    static func visibleURLs(_ candidates: [String], failed: Set<String>) -> [String] {
        let healthy = candidates.filter { !failed.contains($0) }
        return healthy.count >= gridCount ? Array(healthy.prefix(gridCount)) : Array(healthy.prefix(1))
    }

    /// The size each drawn photo is decoded at: a quarter of the frame in a grid, the whole frame otherwise.
    static func cellSize(forPhotoCount count: Int, frame: CGSize) -> CGSize {
        count >= gridCount ? CGSize(width: frame.width / 2, height: frame.height / 2) : frame
    }
}
