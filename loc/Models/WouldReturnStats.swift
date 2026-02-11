//
//  WouldReturnStats.swift
//  loc
//
//  Aggregate statistics for "would go back" sentiment across place reviews
//

import Foundation

struct WouldReturnStats: Equatable {
    let wouldReturnCount: Int
    let wouldNotReturnCount: Int

    var totalResponses: Int {
        wouldReturnCount + wouldNotReturnCount
    }

    var hasData: Bool {
        totalResponses > 0
    }

    var wouldReturnPercentage: Double {
        guard totalResponses > 0 else { return 0.0 }
        return Double(wouldReturnCount) / Double(totalResponses)
    }

    var formattedPercentage: String {
        "\(Int(round(wouldReturnPercentage * 100)))%"
    }

    var formattedNegativePercentage: String {
        "\(Int(round((1.0 - wouldReturnPercentage) * 100)))%"
    }

    /// Computes aggregate would-return stats from a collection of posts.
    static func from(posts: [PlacePost]) -> WouldReturnStats {
        var wouldReturn = 0
        var wouldNot = 0
        for post in posts {
            guard let value = post.wouldReturn else { continue }
            if value {
                wouldReturn += 1
            } else {
                wouldNot += 1
            }
        }
        return WouldReturnStats(wouldReturnCount: wouldReturn, wouldNotReturnCount: wouldNot)
    }
}
