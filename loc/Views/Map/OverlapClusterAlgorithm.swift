//
//  OverlapClusterAlgorithm.swift
//  loc
//
//  Screen-space, footprint-aware clustering for GMUClusterManager. Replaces
//  GMUNonHierarchicalDistanceBasedAlgorithm, which (a) used a fixed 20pt radius, far smaller
//  than our 44-60pt pins, and (b) clusters at the *rounded integer* zoom GMUClusterManager
//  passes in, so between integer zoom levels pins could sit up to ~1.4x closer than it
//  assumed. Here two markers merge whenever their on-screen rects (actual icon size, incl.
//  bottom-anchored photo pins) would touch at the map's exact current zoom; clusters are
//  then re-checked against each other until nothing overlaps.
//

import Foundation
import CoreLocation
import GoogleMaps
import GoogleMapsUtils

final class OverlapClusterAlgorithm: NSObject, GMUClusterAlgorithm {
    /// Visual footprint of an item's marker in points and where it sits relative to the coordinate.
    struct Footprint {
        var size: CGSize
        /// true = marker hangs above the coordinate (bottom anchor), false = centered on it.
        var bottomAnchored: Bool
    }

    weak var mapView: GMSMapView?
    /// Supplies the real rendered size (falls back to layer defaults).
    var footprint: (MapAnnotationItem) -> Footprint = OverlapClusterAlgorithm.defaultFootprint
    /// Extra breathing room so pins don't even kiss.
    var gap: CGFloat = 4
    /// Cluster badge diameter (ClusterBadgeView).
    var badgeSize: CGFloat = 46

    private var items: [String: MapAnnotationItem] = [:]

    // MARK: GMUClusterAlgorithm

    @objc(addItems:) func add(_ newItems: [GMUClusterItem]) {
        for case let item as MapAnnotationItem in newItems { items[item.stableId] = item }
    }

    @objc(removeItem:) func remove(_ item: GMUClusterItem) {
        if let item = item as? MapAnnotationItem { items.removeValue(forKey: item.stableId) }
    }

    func clearItems() { items.removeAll() }

    @objc(clustersAtZoom:) func clusters(atZoom zoom: Float) -> [GMUCluster] {
        // Use the exact zoom, not the rounded integer GMUClusterManager hands us.
        let z = Double(mapView?.camera.zoom ?? zoom)
        let worldSize = 256.0 * pow(2.0, z)

        struct Box {
            var members: [MapAnnotationItem]
            var sumX: Double, sumY: Double
            var rect: CGRect
        }

        func project(_ c: CLLocationCoordinate2D) -> CGPoint {
            let x = (c.longitude + 180) / 360 * worldSize
            let lat = max(min(c.latitude, 85.0511), -85.0511) * .pi / 180
            let y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * worldSize
            return CGPoint(x: x, y: y)
        }
        func itemRect(_ item: MapAnnotationItem, at p: CGPoint) -> CGRect {
            let f = footprint(item)
            let originY = f.bottomAnchored ? p.y - f.size.height : p.y - f.size.height / 2
            return CGRect(x: p.x - f.size.width / 2, y: originY, width: f.size.width, height: f.size.height)
                .insetBy(dx: -gap / 2, dy: -gap / 2)
        }
        func badgeRect(_ b: Box) -> CGRect {
            let n = Double(b.members.count)
            let c = CGPoint(x: b.sumX / n, y: b.sumY / n)
            let s = badgeSize + gap
            return CGRect(x: c.x - s / 2, y: c.y - s / 2, width: s, height: s)
        }

        // Stable order so reclustering the same view never shuffles groupings (no jitter).
        let ordered = items.values.sorted { $0.stableId < $1.stableId }
        var boxes: [Box] = []
        boxes.reserveCapacity(ordered.count)

        // Spatial hash over box centers; cell >= largest footprint so a 3x3 lookup is enough.
        let cell: Double = 140
        var grid: [Int64: [Int]] = [:]
        func key(_ p: CGPoint) -> (Int64, Int64) { (Int64((Double(p.x) / cell).rounded(.down)), Int64((Double(p.y) / cell).rounded(.down))) }
        func hash(_ k: (Int64, Int64)) -> Int64 { k.0 &* 73_856_093 ^ k.1 &* 19_349_663 }

        for item in ordered {
            let p = project(item.position)
            let r = itemRect(item, at: p)
            let k = key(p)
            var joined = false
            search: for dx in -1...1 {
                for dy in -1...1 {
                    for idx in grid[hash((k.0 + Int64(dx), k.1 + Int64(dy)))] ?? [] where boxes[idx].rect.intersects(r) {
                        boxes[idx].members.append(item)
                        boxes[idx].sumX += Double(p.x); boxes[idx].sumY += Double(p.y)
                        boxes[idx].rect = badgeRect(boxes[idx])
                        joined = true
                        break search
                    }
                }
            }
            if !joined {
                boxes.append(Box(members: [item], sumX: Double(p.x), sumY: Double(p.y), rect: r))
                grid[hash(k), default: []].append(boxes.count - 1)
            }
        }

        // Merge passes: centroid shifts can make badges overlap neighbours; repeat until stable.
        for _ in 0..<6 {
            var merged = false
            var i = 0
            while i < boxes.count {
                var j = i + 1
                while j < boxes.count {
                    if boxes[i].rect.intersects(boxes[j].rect) {
                        boxes[i].members += boxes[j].members
                        boxes[i].sumX += boxes[j].sumX; boxes[i].sumY += boxes[j].sumY
                        boxes[i].rect = badgeRect(boxes[i])
                        boxes.remove(at: j)
                        merged = true
                    } else {
                        j += 1
                    }
                }
                i += 1
            }
            if !merged { break }
        }

        return boxes.map { box in
            let lat = box.members.map(\.position.latitude).reduce(0, +) / Double(box.members.count)
            let lon = box.members.map(\.position.longitude).reduce(0, +) / Double(box.members.count)
            let position = box.members.count == 1 ? box.members[0].position
                : CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let cluster = GMUStaticCluster(position: position)
            box.members.forEach { cluster.addItem($0) }
            return cluster
        }
    }

    // MARK: Defaults

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
