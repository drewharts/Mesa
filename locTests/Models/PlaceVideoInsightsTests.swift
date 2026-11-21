//
//  PlaceVideoInsightsTests.swift
//  locTests
//
//  Decoding (old and new backend shapes) and aggregation of "From videos" insights.
//

import XCTest
@testable import loc

final class PlaceVideoInsightsTests: XCTestCase {

    private func decodeInsights(_ json: String) throws -> PlaceInsights {
        try JSONDecoder().decode(PlaceInsights.self, from: Data(json.utf8))
    }

    private let oldShape = #"""
    {"place_id":"P1","take":null,"top_dishes":[{"name":"Rigatoni","count":1}],
     "mentions":[{"video_id":"7212345678901234567","source":"tiktok","source_url":"https://www.tiktok.com/@a/video/7212345678901234567",
       "thumbnail_url":null,"author":"a","dishes":["Rigatoni"],"tip":"Go early","vibe":"loud","timestamp_seconds":null}],
     "photos":[]}
    """#

    private let newShape = #"""
    {"place_id":"P1","mentions":[
      {"video_id":"7212345678901234567","source":"tiktok","source_url":"https://vm.tiktok.com/x","author":"a","dishes":["Rigatoni"],"tip":"Go early",
       "insights":{"v":1,"dishes":[{"name":"Rigatoni","quote":"best pasta"}],"tips":["Go early","Cash only"],"prices":["$18 rigatoni"],
                   "wait":"30 min line","occasions":["date night"],"warnings":["loud"],"quote":"Worth the wait"}},
      {"video_id":"CxYz123","source":"instagram","source_url":"https://www.instagram.com/reel/CxYz123/","author":"@b","dishes":["rigatoni","Tiramisu"],"tip":null}
    ]}
    """#

    func testOldShapeStillDecodesAndRenders() throws {
        let insights = try decodeInsights(oldShape)
        XCTAssertNil(insights.mentions?.first?.insights)
        let summary = PlaceVideoInsightsSummary.build(mentions: insights.mentions ?? [])
        XCTAssertEqual(summary.dishChips, ["Rigatoni"])
        XCTAssertEqual(summary.tips, ["Go early"])
        XCTAssertEqual(summary.cards.count, 1)
        XCTAssertNil(summary.cards[0].quote)
        XCTAssertFalse(summary.cards[0].isFromYourImport)
    }

    func testNewShapeAggregates() throws {
        let mentions = try decodeInsights(newShape).mentions ?? []
        let summary = PlaceVideoInsightsSummary.build(mentions: mentions)
        XCTAssertEqual(summary.dishChips.first, "Rigatoni ×2")
        XCTAssertTrue(summary.dishChips.contains("Tiramisu"))
        XCTAssertEqual(summary.tips, ["Go early", "Cash only"])
        XCTAssertEqual(summary.prices, ["$18 rigatoni"])
        XCTAssertEqual(summary.warnings, ["loud"])
        XCTAssertEqual(summary.occasions, ["date night"])
        XCTAssertEqual(summary.cards.first?.quote, "Worth the wait")
        XCTAssertEqual(summary.cards.last?.creator, "@b")
        XCTAssertEqual(summary.cards.last?.platformLabel, "Instagram")
    }

    func testYourImportMatchesByIdAndLeads() throws {
        let mentions = try decodeInsights(newShape).mentions ?? []
        let summary = PlaceVideoInsightsSummary.build(
            mentions: mentions,
            importedURLs: ["https://www.instagram.com/reel/CxYz123/?igsh=abc"])
        XCTAssertEqual(summary.cards.first?.id, "CxYz123")
        XCTAssertTrue(summary.cards.first?.isFromYourImport == true)
        XCTAssertFalse(summary.cards.last?.isFromYourImport == true)
    }

    func testEmptyMentionsGiveEmptySummary() throws {
        let m = try decodeInsights(#"{"mentions":[{"video_id":"1234567","dishes":[],"tip":null}]}"#).mentions ?? []
        XCTAssertTrue(PlaceVideoInsightsSummary.build(mentions: m).isEmpty)
        XCTAssertTrue(PlaceVideoInsightsSummary.build(mentions: []).isEmpty)
    }

    func testPlatformLabels() {
        XCTAssertEqual(PlaceVideoInsightsSummary.platformLabel(for: "tiktok"), "TikTok")
        XCTAssertEqual(PlaceVideoInsightsSummary.platformLabel(for: nil), "Video")
    }
}
