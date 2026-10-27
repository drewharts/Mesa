//
//  GroupPick.swift
//  loc
//
//  State of a group decision as returned by the get_group_pick / vote_group_pick RPCs.
//

import Foundation

struct GroupPickTally: Codable, Equatable {
    let placeId: String
    let yes: Int
    let no: Int

    enum CodingKeys: String, CodingKey {
        case placeId = "place_id"
        case yes
        case no
    }
}

struct GroupPick: Codable, Equatable, Identifiable {
    let id: String
    let creatorId: String
    let title: String?
    let placeIds: [String]
    let decideAt: Date?
    let decidedPlaceId: String?
    let decidedAt: Date?
    let memberCount: Int
    let tallies: [GroupPickTally]
    let myVotes: [String: Bool]

    var isDecided: Bool { decidedPlaceId != nil }

    enum CodingKeys: String, CodingKey {
        case id
        case creatorId = "creator_id"
        case title
        case placeIds = "place_ids"
        case decideAt = "decide_at"
        case decidedPlaceId = "decided_place_id"
        case decidedAt = "decided_at"
        case memberCount = "member_count"
        case tallies
        case myVotes = "my_votes"
    }

    /// Decodes the RPC JSON, tolerating missing optional collections and Postgres timestamp formats.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        creatorId = try c.decode(String.self, forKey: .creatorId)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        placeIds = try c.decodeIfPresent([String].self, forKey: .placeIds) ?? []
        decideAt = GroupPick.parseDate(try c.decodeIfPresent(String.self, forKey: .decideAt))
        decidedPlaceId = try c.decodeIfPresent(String.self, forKey: .decidedPlaceId)
        decidedAt = GroupPick.parseDate(try c.decodeIfPresent(String.self, forKey: .decidedAt))
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        tallies = try c.decodeIfPresent([GroupPickTally].self, forKey: .tallies) ?? []
        myVotes = try c.decodeIfPresent([String: Bool].self, forKey: .myVotes) ?? [:]
    }

    /// Encodes dates back as ISO-8601 strings.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(creatorId, forKey: .creatorId)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encode(placeIds, forKey: .placeIds)
        try c.encodeIfPresent(decideAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .decideAt)
        try c.encodeIfPresent(decidedPlaceId, forKey: .decidedPlaceId)
        try c.encodeIfPresent(decidedAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .decidedAt)
        try c.encode(memberCount, forKey: .memberCount)
        try c.encode(tallies, forKey: .tallies)
        try c.encode(myVotes, forKey: .myVotes)
    }

    /// Parses Postgres timestamptz JSON strings (with or without fractional seconds).
    static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: raw) { return date }
        // Postgres emits microseconds; drop the fraction if the formatter rejects it.
        let trimmed = raw.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return plain.date(from: trimmed)
    }

    /// Returns the tally for a place, or zeros if none.
    func tally(for placeId: String) -> GroupPickTally {
        tallies.first { $0.placeId.lowercased() == placeId.lowercased() }
            ?? GroupPickTally(placeId: placeId, yes: 0, no: 0)
    }

    /// Returns the current user's vote on a place, if any.
    func myVote(for placeId: String) -> Bool? {
        myVotes.first { $0.key.lowercased() == placeId.lowercased() }?.value
    }
}
