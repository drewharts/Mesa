//
//  DateRangePickerViewModelTests.swift
//  locTests
//
//  Tests for DateRangePickerViewModel: visualState, handleDayTap state machine, and grid computation.
//

import XCTest
@testable import loc

@MainActor
final class DateRangePickerViewModelTests: XCTestCase {

    // MARK: - Helpers

    private let calendar = Calendar.current

    /// Returns a future date guaranteed to not be in the past.
    private func futureDate(daysFromNow days: Int) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: days, to: Date())!)
    }

    /// Returns the start of today.
    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    // MARK: - Initialization

    func testInit_Empty() {
        let vm = DateRangePickerViewModel()
        XCTAssertEqual(vm.selectionState, .empty)
    }

    func testInit_WithStartDate() {
        let start = futureDate(daysFromNow: 5)
        let vm = DateRangePickerViewModel(startDate: start)
        if case .startOnly(let s) = vm.selectionState {
            XCTAssertEqual(s, start)
        } else {
            XCTFail("Expected .startOnly, got \(vm.selectionState)")
        }
    }

    func testInit_WithBothDates() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)
        if case .complete(let s, let e) = vm.selectionState {
            XCTAssertEqual(s, start)
            XCTAssertEqual(e, end)
        } else {
            XCTFail("Expected .complete, got \(vm.selectionState)")
        }
    }

    // MARK: - handleDayTap State Machine

    func testHandleDayTap_EmptyToStartOnly() {
        let vm = DateRangePickerViewModel()
        let day = futureDate(daysFromNow: 5)

        vm.handleDayTap(day)

        if case .startOnly(let s) = vm.selectionState {
            XCTAssertEqual(s, day)
        } else {
            XCTFail("Expected .startOnly after tapping from empty")
        }
    }

    func testHandleDayTap_StartOnlyToComplete() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start)

        vm.handleDayTap(end)

        if case .complete(let s, let e) = vm.selectionState {
            XCTAssertEqual(s, start)
            XCTAssertEqual(e, end)
        } else {
            XCTFail("Expected .complete after tapping later date")
        }
    }

    func testHandleDayTap_StartOnlyTapSameDate_ClearsToEmpty() {
        let start = futureDate(daysFromNow: 5)
        let vm = DateRangePickerViewModel(startDate: start)

        vm.handleDayTap(start)

        XCTAssertEqual(vm.selectionState, .empty)
    }

    func testHandleDayTap_StartOnlyTapEarlierDate_NewStart() {
        let originalStart = futureDate(daysFromNow: 10)
        let earlierDate = futureDate(daysFromNow: 5)
        let vm = DateRangePickerViewModel(startDate: originalStart)

        vm.handleDayTap(earlierDate)

        if case .startOnly(let s) = vm.selectionState {
            XCTAssertEqual(s, earlierDate)
        } else {
            XCTFail("Expected .startOnly with earlier date")
        }
    }

    func testHandleDayTap_CompleteToStartOnly() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let newDay = futureDate(daysFromNow: 15)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)

        vm.handleDayTap(newDay)

        if case .startOnly(let s) = vm.selectionState {
            XCTAssertEqual(s, newDay)
        } else {
            XCTFail("Expected .startOnly after tapping from complete")
        }
    }

    func testHandleDayTap_PastDate_Ignored() {
        let vm = DateRangePickerViewModel()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!

        vm.handleDayTap(yesterday)

        XCTAssertEqual(vm.selectionState, .empty)
    }

    // MARK: - visualState

    func testVisualState_NilDate_Placeholder() {
        let vm = DateRangePickerViewModel()
        XCTAssertEqual(vm.visualState(for: nil), .placeholder)
    }

    func testVisualState_PastDate_Disabled() {
        let vm = DateRangePickerViewModel()
        let pastDate = calendar.date(byAdding: .day, value: -5, to: Date())!
        XCTAssertEqual(vm.visualState(for: pastDate), .disabled)
    }

    func testVisualState_Empty_Unselected() {
        let vm = DateRangePickerViewModel()
        let futureDay = futureDate(daysFromNow: 10)
        XCTAssertEqual(vm.visualState(for: futureDay), .unselected)
    }

    func testVisualState_StartOnly_StartDate() {
        let start = futureDate(daysFromNow: 5)
        let vm = DateRangePickerViewModel(startDate: start)
        XCTAssertEqual(vm.visualState(for: start), .startDate)
    }

    func testVisualState_StartOnly_OtherDate_Unselected() {
        let start = futureDate(daysFromNow: 5)
        let other = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start)
        XCTAssertEqual(vm.visualState(for: other), .unselected)
    }

    func testVisualState_Complete_StartDate() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)
        XCTAssertEqual(vm.visualState(for: start), .startDate)
    }

    func testVisualState_Complete_EndDate() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)
        XCTAssertEqual(vm.visualState(for: end), .endDate)
    }

    func testVisualState_Complete_InRange() {
        let start = futureDate(daysFromNow: 5)
        let mid = futureDate(daysFromNow: 7)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)
        XCTAssertEqual(vm.visualState(for: mid), .inRange)
    }

    func testVisualState_Complete_OutOfRange() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let outside = futureDate(daysFromNow: 15)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)
        XCTAssertEqual(vm.visualState(for: outside), .unselected)
    }

    // MARK: - cellsForDisplayedMonth

    func testCellsForDisplayedMonth_GridDivisibleBy7() {
        let vm = DateRangePickerViewModel()
        let cells = vm.cellsForDisplayedMonth()
        XCTAssertEqual(cells.count % 7, 0, "Grid should always be a multiple of 7")
    }

    func testCellsForDisplayedMonth_HasCorrectDayCount() {
        // Set displayed month to a known month (January 2026 has 31 days)
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = jan2026

        let cells = vm.cellsForDisplayedMonth()
        let dayCells = cells.filter { $0.dayOfMonth != nil }
        XCTAssertEqual(dayCells.count, 31)
    }

    func testCellsForDisplayedMonth_February2026() {
        // February 2026 has 28 days
        let feb2026 = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = feb2026

        let cells = vm.cellsForDisplayedMonth()
        let dayCells = cells.filter { $0.dayOfMonth != nil }
        XCTAssertEqual(dayCells.count, 28)
        XCTAssertEqual(cells.count % 7, 0)
    }

    func testCellsForDisplayedMonth_LeapYear() {
        // February 2028 is a leap year → 29 days
        let feb2028 = calendar.date(from: DateComponents(year: 2028, month: 2, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = feb2028

        let cells = vm.cellsForDisplayedMonth()
        let dayCells = cells.filter { $0.dayOfMonth != nil }
        XCTAssertEqual(dayCells.count, 29)
    }

    func testCellsForDisplayedMonth_PlaceholderCellsHaveNilDate() {
        let vm = DateRangePickerViewModel()
        let cells = vm.cellsForDisplayedMonth()

        for cell in cells where cell.dayOfMonth == nil {
            XCTAssertNil(cell.date)
            XCTAssertFalse(cell.isCurrentMonth)
        }
    }

    func testCellsForDisplayedMonth_DayCellsAreCurrentMonth() {
        let vm = DateRangePickerViewModel()
        let cells = vm.cellsForDisplayedMonth()

        for cell in cells where cell.dayOfMonth != nil {
            XCTAssertTrue(cell.isCurrentMonth)
            XCTAssertNotNil(cell.date)
        }
    }

    // MARK: - weeksForDisplayedMonth

    func testWeeksForDisplayedMonth_AllRowsHave7() {
        let vm = DateRangePickerViewModel()
        let weeks = vm.weeksForDisplayedMonth()

        for week in weeks {
            XCTAssertEqual(week.count, 7)
        }
    }

    // MARK: - Month Navigation

    func testAdvanceMonth() {
        let jan2026 = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = jan2026

        vm.advanceMonth()

        let month = calendar.component(.month, from: vm.displayedMonth)
        XCTAssertEqual(month, 2)
    }

    func testRetreatMonth() {
        let mar2026 = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = mar2026

        vm.retreatMonth()

        let month = calendar.component(.month, from: vm.displayedMonth)
        XCTAssertEqual(month, 2)
    }

    // MARK: - Labels

    func testMonthYearLabel() {
        let jul2026 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = jul2026

        XCTAssertEqual(vm.monthYearLabel, "July 2026")
    }

    func testAbbreviatedMonthLabel() {
        let jul2026 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = jul2026

        XCTAssertEqual(vm.abbreviatedMonthLabel, "Jul")
    }

    func testYearLabel() {
        let jul2026 = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        let vm = DateRangePickerViewModel()
        vm.displayedMonth = jul2026

        XCTAssertEqual(vm.yearLabel, "2026")
    }

    // MARK: - Reset

    func testReset_ClearsSelection() {
        let start = futureDate(daysFromNow: 5)
        let end = futureDate(daysFromNow: 10)
        let vm = DateRangePickerViewModel(startDate: start, endDate: end)

        vm.reset()

        XCTAssertEqual(vm.selectionState, .empty)
    }
}
