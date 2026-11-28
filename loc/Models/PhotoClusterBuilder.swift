//  PhotoClusterBuilder.swift
//  loc
//
//  Pure, unit-testable grouping of photos into visits by place and time.

import Foundation

struct PhotoClusterDraft: Equatable {
    var latitude: Double
    var longitude: Double
    var photoIndices: [Int]
    /// Best (smallest) known GPS error among members, if any member recorded one.
    var bestAccuracyMeters: Double?
    var firstCapturedAt: Date?
    var utcOffsetSeconds: Int?
}

enum PhotoClusterBuilder {
    static let maxDistanceMeters = 60.0
    static let maxGapSeconds: TimeInterval = 45 * 60
    /// Accuracy assumed for weighting when a photo does not record one.
    static let defaultAccuracyMeters = 25.0
    static let minAccuracyMeters = 5.0

    private struct Member { let index: Int; let sample: PhotoSample }

    private struct Working {
        var members: [Member]
        var lat: Double
        var lng: Double
        var lastTime: Date?
    }

    /// Groups samples into clusters (nil entries are photos without GPS and come back unassigned).
    static func build(samples: [PhotoSample?]) -> (clusters: [PhotoClusterDraft], unassigned: [Int]) {
        let unassigned = samples.indices.filter { samples[$0] == nil }
        let located = samples.enumerated().compactMap { i, s in s.map { Member(index: i, sample: $0) } }
        let timed = located.filter { $0.sample.capturedAt != nil }
            .sorted { ($0.sample.capturedAt!, $0.index) < ($1.sample.capturedAt!, $1.index) }
        let untimed = located.filter { $0.sample.capturedAt == nil }

        var working: [Working] = []
        for member in timed + untimed { place(member, into: &working) }
        return (working.map(draft), unassigned)
    }

    /// Weighted center of samples, weighting each by 1/accuracy.
    static func weightedCenter(of samples: [PhotoSample]) -> (latitude: Double, longitude: Double) {
        var wSum = 0.0, lat = 0.0, lng = 0.0
        for s in samples {
            let w = 1 / max(s.accuracyMeters ?? defaultAccuracyMeters, minAccuracyMeters)
            wSum += w; lat += s.latitude * w; lng += s.longitude * w
        }
        guard wSum > 0 else { return (0, 0) }
        return (lat / wSum, lng / wSum)
    }

    /// Great-circle distance in meters (Haversine).
    static func distanceMeters(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 6371000.0 * 2 * atan2(sqrt(a), sqrt(1 - a))
    }

    /// Adds a member to the nearest compatible cluster, or starts a new one.
    private static func place(_ member: Member, into clusters: inout [Working]) {
        var best: (index: Int, distance: Double)?
        for i in clusters.indices where isCompatible(member, with: clusters[i]) {
            let d = distanceMeters(clusters[i].lat, clusters[i].lng, member.sample.latitude, member.sample.longitude)
            if d <= maxDistanceMeters, d < (best?.distance ?? .infinity) { best = (i, d) }
        }
        guard let target = best?.index else {
            clusters.append(Working(members: [member], lat: member.sample.latitude,
                                    lng: member.sample.longitude, lastTime: member.sample.capturedAt))
            return
        }
        clusters[target].members.append(member)
        let center = weightedCenter(of: clusters[target].members.map(\.sample))
        clusters[target].lat = center.latitude
        clusters[target].lng = center.longitude
        if let t = member.sample.capturedAt { clusters[target].lastTime = max(clusters[target].lastTime ?? t, t) }
    }

    /// A timed photo needs a timeless cluster or one whose last photo is within the time gap.
    private static func isCompatible(_ member: Member, with cluster: Working) -> Bool {
        guard let t = member.sample.capturedAt, let last = cluster.lastTime else { return true }
        return abs(t.timeIntervalSince(last)) <= maxGapSeconds
    }

    /// Converts working state into an immutable draft.
    private static func draft(_ w: Working) -> PhotoClusterDraft {
        let first = w.members.compactMap { m in m.sample.capturedAt.map { (m, $0) } }.min { $0.1 < $1.1 }
        return PhotoClusterDraft(
            latitude: w.lat, longitude: w.lng,
            photoIndices: w.members.map(\.index).sorted(),
            bestAccuracyMeters: w.members.compactMap(\.sample.accuracyMeters).min(),
            firstCapturedAt: first?.1,
            utcOffsetSeconds: first?.0.sample.utcOffsetSeconds
        )
    }
}
