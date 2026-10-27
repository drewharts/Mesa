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

/// How a decided pick was settled (`outcome` from the 20261027 migration; nil on older servers).
enum GroupPickOutcome: String, Codable, Equatable {
    case winner
    case tieBreak = "tie_break"
    case noMatch = "no_match"
}

/// One person in a group pick with their votes (`members` from the 20261027 migration).
struct GroupPickMember: Codable, Equatable, Identifiable {
    let userId: String
    let firstName: String?
    let lastName: String?
    let votedCount: Int
    let votes: [String: Bool]

    var id: String { userId.lowercased() }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case firstName = "first_name"
        case lastName = "last_name"
        case votedCount = "voted_count"
        case votes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId = try c.decode(String.self, forKey: .userId)
        firstName = try c.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try c.decodeIfPresent(String.self, forKey: .lastName)
        votedCount = try c.decodeIfPresent(Int.self, forKey: .votedCount) ?? 0
        votes = try c.decodeIfPresent([String: Bool].self, forKey: .votes) ?? [:]
    }

    /// "Grace" (first name), falling back to "Someone".
    var displayName: String {
        let first = (firstName ?? "").trimmingCharacters(in: .whitespaces)
        return ScreenshotPrivacy.name(first.isEmpty ? "Someone" : first, userId: userId)
    }

    /// This person's vote on a place, if any.
    func vote(for placeId: String) -> Bool? {
        votes.first { $0.key.lowercased() == placeId.lowercased() }?.value
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
    /// Result details below come from the 20261027 migration and are empty/nil on older servers.
    let outcomeRaw: String?
    let decidedReason: String?
    let members: [GroupPickMember]
    let waitingOn: [String]
    let addedBy: [String: String]

    /// Decided with a winner, a tie-break winner, or closed with no match.
    var isDecided: Bool { decidedAt != nil || decidedPlaceId != nil }
    /// True when the group settled on a place.
    var hasWinner: Bool { decidedPlaceId != nil }
    var outcome: GroupPickOutcome? {
        if let raw = outcomeRaw, let known = GroupPickOutcome(rawValue: raw) { return known }
        if hasWinner { return .winner }
        return isDecided ? .noMatch : nil
    }
    /// Closed because nobody liked any place: the group can add options and reopen it.
    var isNoMatch: Bool { isDecided && !hasWinner }

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
        case outcomeRaw = "outcome"
        case decidedReason = "decided_reason"
        case members
        case waitingOn = "waiting_on"
        case addedBy = "added_by"
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
        outcomeRaw = try c.decodeIfPresent(String.self, forKey: .outcomeRaw)
        decidedReason = try c.decodeIfPresent(String.self, forKey: .decidedReason)
        members = (try? c.decodeIfPresent([GroupPickMember].self, forKey: .members)) ?? []
        waitingOn = (try? c.decodeIfPresent([String].self, forKey: .waitingOn)) ?? []
        addedBy = (try? c.decodeIfPresent([String: String].self, forKey: .addedBy)) ?? [:]
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
        try c.encodeIfPresent(outcomeRaw, forKey: .outcomeRaw)
        try c.encodeIfPresent(decidedReason, forKey: .decidedReason)
        try c.encode(members, forKey: .members)
        try c.encode(waitingOn, forKey: .waitingOn)
        try c.encode(addedBy, forKey: .addedBy)
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

extension GroupPick {
    /// Members who said yes to a place.
    func yesVoters(for placeId: String) -> [GroupPickMember] {
        members.filter { $0.vote(for: placeId) == true }
    }

    /// Members who said no to a place.
    func noVoters(for placeId: String) -> [GroupPickMember] {
        members.filter { $0.vote(for: placeId) == false }
    }

    /// Members who have not voted on every place yet.
    func pendingMembers(excluding userId: String?) -> [GroupPickMember] {
        let me = userId?.lowercased()
        let pending = Set(waitingOn.map { $0.lowercased() })
        return members.filter { pending.contains($0.userId.lowercased()) && $0.userId.lowercased() != me }
    }

    /// True when the user has voted on every place.
    func hasVotedOnAll(userId: String?) -> Bool {
        guard let userId else { return false }
        return !waitingOn.contains { $0.lowercased() == userId.lowercased() } && !placeIds.isEmpty && placeIds.allSatisfy { myVote(for: $0) != nil }
    }
}

/// One row of "your group picks" (my_group_picks RPC): active or recently decided.
struct GroupPickSummary: Codable, Equatable, Identifiable {
    let id: String
    let title: String?
    let decidedPlaceId: String?
    let outcomeRaw: String?
    let decidedAt: Date?
    let decideAt: Date?
    let memberCount: Int
    let placeCount: Int
    let votedCount: Int
    let placeName: String?

    enum CodingKeys: String, CodingKey {
        case id, title
        case decidedPlaceId = "decided_place_id"
        case outcomeRaw = "outcome"
        case decidedAt = "decided_at"
        case decideAt = "decide_at"
        case memberCount = "member_count"
        case placeCount = "place_count"
        case votedCount = "voted_count"
        case placeName = "place_name"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        decidedPlaceId = try c.decodeIfPresent(String.self, forKey: .decidedPlaceId)
        outcomeRaw = try c.decodeIfPresent(String.self, forKey: .outcomeRaw)
        decidedAt = GroupPick.parseDate(try c.decodeIfPresent(String.self, forKey: .decidedAt))
        decideAt = GroupPick.parseDate(try c.decodeIfPresent(String.self, forKey: .decideAt))
        memberCount = try c.decodeIfPresent(Int.self, forKey: .memberCount) ?? 0
        placeCount = try c.decodeIfPresent(Int.self, forKey: .placeCount) ?? 0
        votedCount = try c.decodeIfPresent(Int.self, forKey: .votedCount) ?? 0
        placeName = try c.decodeIfPresent(String.self, forKey: .placeName)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(title, forKey: .title)
        try c.encodeIfPresent(decidedPlaceId, forKey: .decidedPlaceId)
        try c.encodeIfPresent(outcomeRaw, forKey: .outcomeRaw)
        try c.encodeIfPresent(decidedAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .decidedAt)
        try c.encodeIfPresent(decideAt.map { ISO8601DateFormatter().string(from: $0) }, forKey: .decideAt)
        try c.encode(memberCount, forKey: .memberCount)
        try c.encode(placeCount, forKey: .placeCount)
        try c.encode(votedCount, forKey: .votedCount)
        try c.encodeIfPresent(placeName, forKey: .placeName)
    }

    var isDecided: Bool { decidedAt != nil || decidedPlaceId != nil }
    var hasWinner: Bool { decidedPlaceId != nil }
    /// Still open and this user has not voted on every place.
    var needsMyVote: Bool { !isDecided && votedCount < placeCount }

    /// Row headline, e.g. "Coffee right now".
    var headline: String { (title?.isEmpty == false ? title : nil) ?? "Group pick" }

    /// Row state line, e.g. "🎉 Blue Bottle won" or "Your vote is needed".
    var statusLine: String {
        if hasWinner { return "🎉 \(placeName ?? "A place") won" }
        if isDecided { return "No match · add more options" }
        if needsMyVote { return "Your vote is needed · \(memberCount) \(memberCount == 1 ? "person" : "people")" }
        if let decideAt { return "Waiting for the others · decides by \(decideAt.formatted(date: .omitted, time: .shortened))" }
        return "Waiting for the others"
    }
}
