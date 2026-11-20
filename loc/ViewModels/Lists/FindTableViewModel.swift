//
//  FindTableViewModel.swift
//  loc
//
//  SMART ViewModel for "Find a table" on a list: the search form (party size, day, time window),
//  the availability search and its loading/results/error state, and opening booking links.
//  Single Responsibility: availability search state. Narrowing the list and map is done by the list
//  view through `scopeIds`; nothing is ever booked in-app.
//

import Foundation
import UIKit

@MainActor
final class FindTableViewModel: ObservableObject {
    /// The quick choices in the sheet.
    enum Preset: String, CaseIterable, Identifiable {
        case tonight = "Tonight"
        case tomorrow = "Tomorrow"
        case pick = "Pick"

        var id: String { rawValue }
    }

    /// What the last search produced.
    struct Results: Equatable {
        let response: TableAvailabilityResponse
        let request: TableAvailabilityRequest
        let withTables: [PlaceTableAvailability]
    }

    /// Where the search is.
    enum SearchState: Equatable {
        case idle
        case loading
        case results(Results)
        case failed
    }

    // MARK: - Published State

    @Published var isFormPresented = false
    @Published private(set) var preset: Preset = .tonight
    @Published var partySize = 2
    @Published private(set) var selection: TableSearchSelection
    @Published private(set) var state: SearchState = .idle
    /// False once the backend has said it does not offer the feature; hides the entry point.
    @Published private(set) var isOffered = TableAvailabilityGate.isOffered

    static let partySizeRange = 1...20

    // MARK: - Private State

    private let service: TableAvailabilityFetching
    private let now: () -> Date
    private let calendar: Calendar
    private var searchTask: Task<Void, Never>?
    private var searchToken = UUID()

    /// Creates the view model with the defaults for "now": today, next half hour through 10:30 PM.
    init(service: TableAvailabilityFetching = TableAvailabilityService.shared,
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.service = service
        self.now = now
        self.calendar = calendar
        self.selection = TableSearchSelection.tonight(now: now(), calendar: calendar)
    }

    // MARK: - Derived State

    /// True while any search mode (loading, results or error) is narrowing the list.
    var isActive: Bool { state != .idle }

    /// True while a search is in flight.
    var isLoading: Bool { state == .loading }

    /// Ids (lowercased) of the places with tables once results are in; nil otherwise (nothing narrowed).
    var scopeIds: Set<String>? {
        guard case .results(let results) = state else { return nil }
        return Set(results.withTables.map(\.id))
    }

    /// Availability for a place (matched case-insensitively), when results are in.
    func availability(for placeId: String) -> PlaceTableAvailability? {
        guard case .results(let results) = state else { return nil }
        return results.withTables.first { $0.id == placeId.lowercased() }
    }

    /// True when the form can be submitted.
    var canSearch: Bool { selection.window.isValid && !isLoading }

    /// "Checked N places on Resy · M have tables" for the results header; nil outside results.
    var resultsSummary: String? {
        guard case .results(let results) = state else { return nil }
        let checked = results.response.checked
        let noun = checked == 1 ? "place" : "places"
        return "Checked \(checked) \(noun) on \(results.response.providerName) · \(results.withTables.count) have tables"
    }

    /// "Fri, Nov 21 · 7:30 PM – 10:30 PM" for the form and the empty state.
    var selectionSummary: String {
        let day = Self.dayFormatter.string(from: selection.date)
        let start = timeText(minutes: selection.window.startMinutes)
        let end = timeText(minutes: selection.window.endMinutes)
        return "\(day) · \(start) – \(end)"
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEMMMd")
        return formatter
    }()

    /// A localized clock time such as "7:30 PM" for minutes after midnight.
    func timeText(minutes: Int) -> String {
        date(forMinutes: minutes).formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Form

    /// Opens the search sheet.
    func presentForm() {
        isFormPresented = true
    }

    /// Applies a preset; "Pick" keeps the current day and times so they can be edited.
    func selectPreset(_ newPreset: Preset) {
        preset = newPreset
        switch newPreset {
        case .tonight: selection = TableSearchSelection.tonight(now: now(), calendar: calendar)
        case .tomorrow: selection = TableSearchSelection.tomorrow(now: now(), calendar: calendar)
        case .pick: break
        }
    }

    /// Sets the day to search (Pick mode).
    func setDate(_ date: Date) {
        selection.date = calendar.startOfDay(for: date)
    }

    /// Sets the start of the window from a time picker; pushes the end later when it would not follow the start.
    func setStart(_ date: Date) {
        let minutes = minutesOfDay(date)
        selection.window.startMinutes = minutes
        if selection.window.endMinutes <= minutes {
            selection.window.endMinutes = min(minutes + 60, 24 * 60 - 1)
        }
    }

    /// Sets the end of the window from a time picker.
    func setEnd(_ date: Date) {
        selection.window.endMinutes = minutesOfDay(date)
    }

    /// A Date carrying the given minutes after midnight on the selected day (for time pickers).
    func date(forMinutes minutes: Int) -> Date {
        calendar.date(byAdding: .minute, value: minutes, to: calendar.startOfDay(for: selection.date)) ?? selection.date
    }

    /// Minutes after midnight of a picker's Date.
    private func minutesOfDay(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // MARK: - Search

    /// Closes the sheet and checks the list's places for the chosen party size, day and window.
    func search(listId: String) {
        guard canSearch else { return }
        isFormPresented = false
        run(listId: listId)
    }

    /// Repeats the last search (used by the error state's retry).
    func retry(listId: String) {
        guard selection.window.isValid else { return }
        run(listId: listId)
    }

    /// Starts a search, cancelling any in flight; only the newest search may publish a result.
    private func run(listId: String) {
        searchTask?.cancel()
        let token = UUID()
        searchToken = token
        state = .loading
        let request = TableAvailabilityRequest.make(partySize: partySize, date: selection.date, window: selection.window, calendar: calendar)
        searchTask = Task { [weak self, service] in
            do {
                let response = try await service.search(listId: listId, request: request)
                self?.finish(token: token, request: request, response: response)
            } catch is CancellationError {
                return
            } catch let error as TableAvailabilityError {
                self?.fail(token: token, error: error)
            } catch {
                if (error as? URLError)?.code == .cancelled { return }
                self?.fail(token: token, error: .failed)
            }
        }
    }

    /// Publishes a successful search unless a newer one replaced it.
    private func finish(token: UUID, request: TableAvailabilityRequest, response: TableAvailabilityResponse) {
        guard token == searchToken else { return }
        if response.allChecksFailed {
            state = .failed
            return
        }
        let withTables = response.placesWithTables
        state = .results(Results(response: response, request: request, withTables: withTables))
    }

    /// Publishes a failure; an unavailable backend hides the entry point and leaves search mode.
    private func fail(token: UUID, error: TableAvailabilityError) {
        guard token == searchToken else { return }
        if error == .unavailable {
            isOffered = false
            state = .idle
        } else {
            state = .failed
        }
    }

    /// Leaves search mode and shows the full list again.
    func exit() {
        searchTask?.cancel()
        searchToken = UUID()
        state = .idle
    }

    // MARK: - Booking

    /// Opens a place's booking page: the Resy app via its universal link when installed, otherwise Safari.
    func openBooking(for availability: PlaceTableAvailability) {
        guard let url = availability.bookingDestination else { return }
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { opened in
            guard !opened else { return }
            UIApplication.shared.open(url)
        }
    }
}
