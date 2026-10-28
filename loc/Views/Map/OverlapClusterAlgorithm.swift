//
//  OverlapClusterAlgorithm.swift
//  loc
//
//  Screen-space, footprint-aware clustering. Two markers merge whenever their on-screen rects
//  (real icon size, incl. bottom-anchored photo pins) would touch at the map's exact zoom.
//
//  Performance design:
//  - The math is a pure function over value snapshots (`OverlapClusterer.compute`), run on a
//    background queue by GoogleMapView.Coordinator; only marker updates touch the main thread.
//  - Greedy assignment and every merge pass use a spatial hash grid: O(n) per pass, no O(n^2).
//  - Only items inside the visible viewport (+50% margin) are clustered at all.
//  - GMUClusterManager still owns the renderer + tap forwarding; this algorithm object just
//    stores items and hands back the latest precomputed clusters instantly.
//

import Foundation
import CoreLocation
import GoogleMaps
import GoogleMapsUtils
import os

enum MapPerf {
    static let log = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "mesa", category: "MapPins")
    static let signposter = OSSignposter(logHandle: log)
}

/// Latest requested clustering generation, readable from the background clusterer to cancel stale runs.
enum OverlapGenerationToken {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var value = 0
    static var current: Int {
        get { lock.lock(); defer { lock.unlock() }; return value }
        set { lock.lock(); value = newValue; lock.unlock() }
    }
}

/// Value-type clustering kernel. Safe to run off the main thread.
enum OverlapClusterer {
    struct Entry: Sendable {
        var x: Double, y: Double          // world points at the current zoom
        var w: Double, h: Double
        var bottomAnchored: Bool
    }

    /// Returns groups of entry indices. Entries must be in a stable order.
    static func compute(_ entries: [Entry], badge: Double, gap: Double, isCancelled: () -> Bool) -> [[Int]] {
        struct Box { var members: [Int]; var sx: Double; var sy: Double; var rect: CGRect; var alive = true
            var cx: Double { sx / Double(members.count) }; var cy: Double { sy / Double(members.count) } }
        let cell = 140.0
        @inline(__always) func k(_ x: Double, _ y: Double) -> SIMD2<Int64> {
            SIMD2(Int64((x / cell).rounded(.down)), Int64((y / cell).rounded(.down)))
        }
        func itemRect(_ e: Entry) -> CGRect {
            let oy = e.bottomAnchored ? e.y - e.h : e.y - e.h / 2
            return CGRect(x: e.x - e.w / 2, y: oy, width: e.w, height: e.h).insetBy(dx: -gap / 2, dy: -gap / 2)
        }
        func badgeRect(_ b: Box) -> CGRect {
            let s = badge + gap
            return CGRect(x: b.cx - s / 2, y: b.cy - s / 2, width: s, height: s)
        }

        var boxes: [Box] = []
        boxes.reserveCapacity(entries.count)
        var grid: [SIMD2<Int64>: [Int]] = [:]

        for (i, e) in entries.enumerated() {
            if i & 255 == 0, isCancelled() { return [] }
            let r = itemRect(e)
            let key = k(e.x, e.y)
            var target: Int?
            outer: for dx in -1...1 { for dy in -1...1 {
                for b in grid[key &+ SIMD2(Int64(dx), Int64(dy))] ?? [] where boxes[b].rect.intersects(r) {
                    target = b; break outer
                }
            } }
            if let t = target {
                boxes[t].members.append(i); boxes[t].sx += e.x; boxes[t].sy += e.y
                boxes[t].rect = badgeRect(boxes[t])
            } else {
                boxes.append(Box(members: [i], sx: e.x, sy: e.y, rect: r))
                grid[key, default: []].append(boxes.count - 1)
            }
        }

        // Merge passes (centroids drift as members join), each O(n) via a rebuilt grid.
        for _ in 0..<6 {
            if isCancelled() { return [] }
            var g: [SIMD2<Int64>: [Int]] = [:]
            for i in boxes.indices where boxes[i].alive { g[k(boxes[i].cx, boxes[i].cy), default: []].append(i) }
            var merged = false
            for i in boxes.indices where boxes[i].alive {
                let key = k(boxes[i].cx, boxes[i].cy)
                for dx in -1...1 { for dy in -1...1 {
                    for j in g[key &+ SIMD2(Int64(dx), Int64(dy))] ?? [] where j > i && boxes[j].alive {
                        guard boxes[i].rect.intersects(boxes[j].rect) else { continue }
                        boxes[i].members += boxes[j].members
                        boxes[i].sx += boxes[j].sx; boxes[i].sy += boxes[j].sy
                        boxes[i].rect = badgeRect(boxes[i])
                        boxes[j].alive = false
                        merged = true
                    }
                } }
            }
            if !merged { break }
        }
        return boxes.filter(\.alive).map(\.members)
    }

    static func project(_ c: CLLocationCoordinate2D, worldSize: Double) -> (Double, Double) {
        let x = (c.longitude + 180) / 360 * worldSize
        let lat = max(min(c.latitude, 85.0511), -85.0511) * .pi / 180
        let y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * worldSize
        return (x, y)
    }
}

/// Item store handed to GMUClusterManager. Returns the latest clusters computed in the background.
final class OverlapClusterAlgorithm: NSObject, GMUClusterAlgorithm {
    struct Footprint {
        var size: CGSize
        var bottomAnchored: Bool
    }

    private(set) var items: [String: MapAnnotationItem] = [:]
    var latestClusters: [GMUCluster] = []

    @objc(addItems:) func add(_ newItems: [GMUClusterItem]) {
        for case let item as MapAnnotationItem in newItems { items[item.stableId] = item }
    }

    @objc(removeItem:) func remove(_ item: GMUClusterItem) {
        if let item = item as? MapAnnotationItem { items.removeValue(forKey: item.stableId) }
    }

    func clearItems() { items.removeAll(); latestClusters = [] }

    @objc(clustersAtZoom:) func clusters(atZoom zoom: Float) -> [GMUCluster] { latestClusters }

    static func defaultFootprint(_ item: MapAnnotationItem) -> Footprint {
        switch item.layer {
        case .network: return Footprint(size: CGSize(width: 52, height: 58), bottomAnchored: true)
        case .community(let m):
            let d: CGFloat = m.saveCount <= 5 ? 38 : (m.saveCount <= 20 ? 46 : 54)
            return Footprint(size: CGSize(width: d, height: d), bottomAnchored: false)
        case .city: return Footprint(size: CGSize(width: 120, height: 36), bottomAnchored: false)
        case .trip, .userLocation: return Footprint(size: CGSize(width: 30, height: 30), bottomAnchored: false)
        }
    }
}
