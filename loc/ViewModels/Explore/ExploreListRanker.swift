//
//  ExploreListRanker.swift
//  loc
//
//  Pure ranking/grouping helpers for the Explore tab.
//  The backend exposes no save or follower counts for lists, so "popular" is derived
//  client-side from place count, with a bonus for lists owned by people the user follows.
//

import Foundation
import CoreLocation

enum ExploreListRanker {
    /// Place-count equivalent added to lists owned by someone the user follows.
    static let followedOwnerBonus = 10.0

    /// Lists within this distance of the user count as "near you".
    static let nearbyRadiusMeters: CLLocationDistance = 80_000

    /// Returns the lists ordered for the given sort option.
    static func sorted(_ lists: [ExploreList], by sort: ExploreListSort, followedOwnerIds: Set<String>) -> [ExploreList] {
        switch sort {
        case .popular:
            return lists.sorted { lhs, rhs in
                let l = score(lhs, followedOwnerIds: followedOwnerIds)
                let r = score(rhs, followedOwnerIds: followedOwnerIds)
                return l != r ? l > r : isNewer(lhs, than: rhs)
            }
        case .newest:
            return lists.sorted { lhs, rhs in
                let l = lhs.createdAt ?? ""
                let r = rhs.createdAt ?? ""
                return l != r ? l > r : lhs.placeCount > rhs.placeCount
            }
        case .mostPlaces:
            return lists.sorted { lhs, rhs in
                lhs.placeCount != rhs.placeCount ? lhs.placeCount > rhs.placeCount : isNewer(lhs, than: rhs)
            }
        }
    }

    /// Returns the lists whose average location is within the nearby radius of `location`.
    static func nearby(_ lists: [ExploreList], to location: CLLocation) -> [ExploreList] {
        lists.filter { list in
            guard let listLocation = list.location else { return false }
            return listLocation.distance(from: location) <= nearbyRadiusMeters
        }
    }

    /// Groups lists by city (folding spelling variants) and returns cities with the most lists first.
    static func cities(from lists: [ExploreList]) -> [ExploreCity] {
        var groups: [String: [String]] = [:]
        for list in lists {
            guard let city = list.city?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty else { continue }
            groups[CityListMatcher.cityKey(city), default: []].append(city)
        }
        let aggregated = groups.map { key, rawNames in
            ExploreCity(
                key: key,
                name: mostCommon(in: rawNames),
                rawNames: Array(Set(rawNames)).sorted(),
                listCount: rawNames.count
            )
        }
        return aggregated.sorted { $0.listCount != $1.listCount ? $0.listCount > $1.listCount : $0.name < $1.name }
    }

    // MARK: - Private

    /// Popularity score: place count plus a bonus for followed owners.
    private static func score(_ list: ExploreList, followedOwnerIds: Set<String>) -> Double {
        Double(list.placeCount) + (followedOwnerIds.contains(list.ownerId) ? followedOwnerBonus : 0)
    }

    /// True when `lhs` was updated more recently than `rhs` (ISO-8601 strings sort chronologically).
    private static func isNewer(_ lhs: ExploreList, than rhs: ExploreList) -> Bool {
        (lhs.updatedAt ?? "") > (rhs.updatedAt ?? "")
    }

    /// The most frequent spelling in `names` (alphabetical on ties, for stable output).
    private static func mostCommon(in names: [String]) -> String {
        let counts = Dictionary(grouping: names, by: { $0 }).mapValues(\.count)
        return counts.max { lhs, rhs in
            lhs.value != rhs.value ? lhs.value < rhs.value : lhs.key > rhs.key
        }?.key ?? ""
    }
}
