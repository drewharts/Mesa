//
//  CalendarGridDataTests.swift
//  locTests
//
//  Tests for CalendarGridData grid layout: weekday alignment, padding, cell properties.
//

import XCTest
@testable import loc

final class CalendarGridDataTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a Trip with the given date strings.
    private func makeTrip(start: String, end: String) -> Trip {
        Trip(
            id: "grid-test",
            name: "Grid Trip",
            ownerId: "owner",
            startDate: Trip.parseDate(start)!,
            endDate: Trip.parseDate(end)!
        )
    }

    /// Returns the real (non-padding) cells from the grid.
    private func realCells(_ grid: CalendarGridData) -> [CalendarGridData.Cell] {
        grid.cells.filter { $0.dayIndex != nil }
    }

    /// Returns the padding (empty) cells from the grid.
    private func paddingCells(_ grid: CalendarGridData) -> [CalendarGridData.Cell] {
        grid.cells.filter { $0.dayIndex == nil }
    }

    // MARK: - Grid Divisible by 7

    func testGridAlwaysDivisibleBy7_SingleDay() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-01"))
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    func testGridAlwaysDivisibleBy7_SevenDays() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-07"))
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    func testGridAlwaysDivisibleBy7_FourteenDays() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-14"))
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    func testGridAlwaysDivisibleBy7_ThirtyDays() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-30"))
        XCTAssertEqual(grid.cells.count % 7, 0)
    }

    // MARK: - Real Cell Count Matches numberOfDays

    func testRealCellCount_SingleDay() {
        let trip = makeTrip(start: "2026-06-15", end: "2026-06-15")
        let grid = CalendarGridData(trip: trip)
        XCTAssertEqual(realCells(grid).count, 1)
    }

    func testRealCellCount_SevenDays() {
        let trip = makeTrip(start: "2026-06-15", end: "2026-06-21")
        let grid = CalendarGridData(trip: trip)
        XCTAssertEqual(realCells(grid).count, 7)
    }

    func testRealCellCount_ThirtyDays() {
        let trip = makeTrip(start: "2026-06-01", end: "2026-06-30")
        let grid = CalendarGridData(trip: trip)
        XCTAssertEqual(realCells(grid).count, 30)
    }

    // MARK: - Sequential dayIndex

    func testDayIndexSequential() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-10"))
        let dayIndices = realCells(grid).compactMap(\.dayIndex)
        XCTAssertEqual(dayIndices, Array(0..<10))
    }

    // MARK: - Padding Cells

    func testPaddingCellsHaveNilProperties() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-03", end: "2026-06-05"))

        for cell in paddingCells(grid) {
            XCTAssertNil(cell.dayIndex)
            XCTAssertNil(cell.dayOfMonth)
            XCTAssertNil(cell.date)
        }
    }

    func testRealCellsHaveNonNilProperties() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-05"))

        for cell in realCells(grid) {
            XCTAssertNotNil(cell.dayIndex)
            XCTAssertNotNil(cell.dayOfMonth)
            XCTAssertNotNil(cell.date)
        }
    }

    // MARK: - Leading Padding for Different Start Weekdays

    func testLeadingPadding_Sunday() {
        // 2026-06-07 is a Sunday (weekday 1) → 0 leading empties
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-07", end: "2026-06-07"))
        // First cell should be real (dayIndex 0)
        XCTAssertEqual(grid.cells.first?.dayIndex, 0)
    }

    func testLeadingPadding_Monday() {
        // 2026-06-01 is a Monday (weekday 2) → 1 leading empty
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-01"))
        XCTAssertNil(grid.cells.first?.dayIndex)
        XCTAssertEqual(grid.cells[1].dayIndex, 0)
    }

    func testLeadingPadding_Saturday() {
        // 2026-06-06 is a Saturday (weekday 7) → 6 leading empties
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-06", end: "2026-06-06"))
        for i in 0..<6 {
            XCTAssertNil(grid.cells[i].dayIndex, "Cell at index \(i) should be padding")
        }
        XCTAssertEqual(grid.cells[6].dayIndex, 0)
    }

    // MARK: - Unique IDs

    func testAllCellIdsAreUnique() {
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-01", end: "2026-06-30"))
        let ids = grid.cells.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "Cell IDs should be unique")
    }

    // MARK: - dayOfMonth Values

    func testDayOfMonth_FirstDayMatchesStartDate() {
        // Trip starts on June 15 → first real cell dayOfMonth = 15
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-15", end: "2026-06-20"))
        let firstReal = realCells(grid).first
        XCTAssertEqual(firstReal?.dayOfMonth, 15)
    }

    func testDayOfMonth_CrossMonth() {
        // Trip spans June 29 - July 2: dayOfMonth should be 29, 30, 1, 2
        let grid = CalendarGridData(trip: makeTrip(start: "2026-06-29", end: "2026-07-02"))
        let dayOfMonths = realCells(grid).compactMap(\.dayOfMonth)
        XCTAssertEqual(dayOfMonths, [29, 30, 1, 2])
    }

    // MARK: - Weekday Headers

    func testWeekdayHeaders() {
        XCTAssertEqual(CalendarGridData.weekdayHeaders, ["S", "M", "T", "W", "T", "F", "S"])
        XCTAssertEqual(CalendarGridData.weekdayHeaders.count, 7)
    }
}
