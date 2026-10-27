//
//  GroupPickTests.swift
//  locTests
//
//  Decoding of group pick payloads from before and after the 20261027 migration,
//  and the state helpers the result screen relies on.
//

import XCTest
@testable import loc

final class GroupPickTests: XCTestCase {
    private func decode(_ json: String) throws -> GroupPick {
        try JSONDecoder().decode(GroupPick.self, from: Data(json.utf8))
    }

    private let oldPayload = """
    {"id":"p1","creator_id":"u1","title":"Coffee right now","place_ids":["a","b","c"],
     "decide_at":"2026-10-27T16:30:00.123456+00:00","decided_place_id":null,"decided_at":null,
     "member_count":2,"tallies":[{"place_id":"a","yes":1,"no":0}],"my_votes":{"a":true}}
    """

    func testOldPayloadDecodesWithDefaults() throws {
        let pick = try decode(oldPayload)
        XCTAssertFalse(pick.isDecided)
        XCTAssertNil(pick.outcome)
        XCTAssertTrue(pick.members.isEmpty)
        XCTAssertTrue(pick.waitingOn.isEmpty)
        XCTAssertEqual(pick.tally(for: "A").yes, 1)
        XCTAssertEqual(pick.myVote(for: "a"), true)
    }

    func testOldDecidedPayloadIsWinner() throws {
        let pick = try decode("""
        {"id":"p1","creator_id":"u1","place_ids":["a"],"decided_place_id":"a","member_count":2}
        """)
        XCTAssertTrue(pick.isDecided)
        XCTAssertTrue(pick.hasWinner)
        XCTAssertEqual(pick.outcome, .winner)
    }

    func testNewDecidedPayloadWithMembers() throws {
        let pick = try decode("""
        {"id":"p1","creator_id":"u1","title":"Coffee right now","place_ids":["a","b","c"],
         "decided_place_id":"a","decided_at":"2026-10-27T16:00:00+00:00","outcome":"winner","decided_reason":"unanimous",
         "member_count":2,"tallies":[{"place_id":"a","yes":2,"no":0}],"my_votes":{"a":true},
         "members":[{"user_id":"U1","first_name":"Drew","last_name":"H","voted_count":1,"votes":{"a":true}},
                    {"user_id":"u2","first_name":"Grace","voted_count":1,"votes":{"a":true}}],
         "waiting_on":[],"added_by":{"c":"u2"}}
        """)
        XCTAssertEqual(pick.outcome, .winner)
        XCTAssertEqual(pick.decidedReason, "unanimous")
        XCTAssertEqual(pick.members.count, 2)
        XCTAssertEqual(pick.yesVoters(for: "A").map(\.displayName), ["Drew", "Grace"])
        XCTAssertEqual(pick.addedBy["c"], "u2")
    }

    func testNoMatchIsDecidedWithoutWinner() throws {
        let pick = try decode("""
        {"id":"p1","creator_id":"u1","place_ids":["a","b","c"],"decided_place_id":null,
         "decided_at":"2026-10-27T16:00:00+00:00","outcome":"no_match","member_count":2}
        """)
        XCTAssertTrue(pick.isDecided)
        XCTAssertFalse(pick.hasWinner)
        XCTAssertTrue(pick.isNoMatch)
        XCTAssertEqual(pick.outcome, .noMatch)
    }

    func testTieBreakOutcome() throws {
        let pick = try decode("""
        {"id":"p1","creator_id":"u1","place_ids":["a","b"],"decided_place_id":"b",
         "decided_at":"2026-10-27T16:00:00+00:00","outcome":"tie_break","decided_reason":"timeout","member_count":2}
        """)
        XCTAssertEqual(pick.outcome, .tieBreak)
    }

    func testPendingMembersExcludeMeAndNameWaiters() throws {
        let pick = try decode("""
        {"id":"p1","creator_id":"u1","place_ids":["a","b"],"member_count":3,
         "my_votes":{"a":true,"b":false},
         "members":[{"user_id":"u1","first_name":"Drew","voted_count":2,"votes":{"a":true,"b":false}},
                    {"user_id":"u2","first_name":"Grace","voted_count":1,"votes":{"a":true}},
                    {"user_id":"u3","first_name":null,"voted_count":0,"votes":{}}],
         "waiting_on":["u2","u3"]}
        """)
        XCTAssertTrue(pick.hasVotedOnAll(userId: "U1"))
        XCTAssertFalse(pick.hasVotedOnAll(userId: "u2"))
        XCTAssertEqual(pick.pendingMembers(excluding: "u1").map(\.displayName), ["Grace", "Someone"])
    }

    func testSummaryStatusLines() throws {
        func summary(_ json: String) throws -> GroupPickSummary {
            try JSONDecoder().decode(GroupPickSummary.self, from: Data(json.utf8))
        }
        let won = try summary(#"{"id":"p","title":"Coffee right now","decided_place_id":"a","decided_at":"2026-10-27T16:00:00+00:00","place_name":"Blue Bottle","member_count":2,"place_count":3,"voted_count":3}"#)
        XCTAssertEqual(won.statusLine, "🎉 Blue Bottle won")
        let noMatch = try summary(#"{"id":"p","decided_at":"2026-10-27T16:00:00+00:00","outcome":"no_match","member_count":2,"place_count":3,"voted_count":3}"#)
        XCTAssertEqual(noMatch.statusLine, "No match · add more options")
        XCTAssertEqual(noMatch.headline, "Group pick")
        let open = try summary(#"{"id":"p","member_count":2,"place_count":3,"voted_count":1}"#)
        XCTAssertTrue(open.needsMyVote)
    }

    func testVibeFromHeadline() {
        XCTAssertEqual(TonightVibe.from(headline: TonightVibe.coffee.headline), .coffee)
        XCTAssertNil(TonightVibe.from(headline: "Something else"))
        XCTAssertNil(TonightVibe.from(headline: nil))
    }
}
