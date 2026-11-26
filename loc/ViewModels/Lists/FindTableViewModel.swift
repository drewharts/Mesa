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

    /// What the search has produced so far (final once `isComplete`).
    struct Results: Equatable {
        let request: TableAvailabilityRequest
        let withTables: [PlaceTableAvailability]
        /// Places the provider checked, as reported by the responses.
        let checkedOnProvider: Int
        let processed: Int
        let total: Int
        let providerName: String
        let failedChunks: Int
        let isComplete: Bool
    }

    /// Where the search is.
    enum SearchState: Equatable {
        case idle
        case loading
        case results(Results)
        case failed
    }

    // MARK: - Published State

    @Published var isFormPresented = false {
        didSet { if !isFormPresented { hasFormAppeared = false } }
    }
    @Published private(set) var preset: Preset = .tonight
    @Published var partySize = 2
    @Published private(set) var selection: TableSearchSelection
    @Published private(set) var state: SearchState = .idle
    /// False once the backend has said it does not offer the feature; hides the entry point.
    @Published private(set) var isOffered = TableAvailabilityGate.isOffered

    static let partySizeRange = 1...20

    // MARK: - Private State

    private let service: TableAvailabilityFetching
    private let cache: TableAvailabilityCache
    private let now: () -> Date
    private let calendar: Calendar
    private var searchTask: Task<Void, Never>?
    private var searchToken = UUID()
    private var accumulator = TableSearchAccumulator(total: 0, chunkCount: 0)
    private var scope = TableSearchScope(placeIds: [], label: nil)
    private var searchKey: TableSearchKey?
    /// True once the form's content has actually appeared on screen (SwiftUI can silently drop a presentation).
    private var hasFormAppeared = false

    /// Creates the view model with the defaults for "now": today, next half hour through 10:30 PM.
    init(service: TableAvailabilityFetching = TableAvailabilityService.shared,
         cache: TableAvailabilityCache = .shared,
         now: @escaping () -> Date = Date.init,
         calendar: Calendar = .current) {
        self.service = service
        self.cache = cache
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

    /// True while chunks are still being checked (results may already be showing).
    var isStreaming: Bool {
        if case .results(let results) = state { return !results.isComplete }
        return false
    }

    /// True when a finished search found no place with tables.
    var hasNoTables: Bool {
        guard case .results(let results) = state else { return false }
        return results.isComplete && results.withTables.isEmpty
    }

    /// Fraction checked (0...1) while streaming; nil when not streaming.
    var progress: Double? {
        guard case .results(let results) = state, !results.isComplete else { return nil }
        return results.total == 0 ? nil : Double(results.processed) / Double(results.total)
    }

    /// "Checking 12 Sushi places" before the first results arrive.
    var loadingText: String {
        "Checking \(placesPhrase(count: scope.placeIds.count))"
    }

    /// "Checked 40 of 117 · 6 have tables" while streaming; "Checked N Sushi places on Resy · M have tables" when done.
    var resultsSummary: String? {
        guard case .results(let results) = state else { return nil }
        let tables = results.withTables.count
        guard results.isComplete else {
            return "Checked \(results.processed) of \(results.total) · \(tables) \(tables == 1 ? "has" : "have") tables"
        }
        var text = "Checked \(placesPhrase(count: results.checkedOnProvider)) on \(results.providerName) · \(tables) have tables"
        if results.failedChunks > 0 { text += " · some couldn't be checked" }
        return text
    }

    /// "12 Sushi places" / "1 place" using the scope's label.
    private func placesPhrase(count: Int) -> String {
        let noun = count == 1 ? "place" : "places"
        return [String(count), scope.label, noun].compactMap { $0 }.joined(separator: " ")
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

    /// Called by the form's content when it appears, confirming the presentation was not dropped.
    func formDidAppear() {
        hasFormAppeared = true
    }

    /// Opens the form (Tonight, party of 2) once the host list sheet has settled, and re-presents it if SwiftUI drops
    /// the presentation while that sheet is still animating in. Returns true when the form is confirmed on screen.
    func presentFormWhenHostSettled(listId: String) async -> Bool {
        guard isOffered else {
            FindTableLog.log("list \(listId): backend does not offer availability (gate closed), form not shown")
            return false
        }
        if state == .idle {
            selectPreset(.tonight)
            partySize = 2
        }
        for attempt in 1...5 {
            try? await Task.sleep(nanoseconds: attempt == 1 ? 700_000_000 : 500_000_000)
            guard !Task.isCancelled else {
                FindTableLog.log("list \(listId): presenter cancelled on attempt \(attempt)")
                return false
            }
            if hasFormAppeared {
                FindTableLog.log("list \(listId): form on screen after \(attempt - 1) re-present(s)")
                return true
            }
            FindTableLog.log("list \(listId): presenting form, attempt \(attempt)")
            isFormPresented = false
            try? await Task.sleep(nanoseconds: 80_000_000)
            isFormPresented = true
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        FindTableLog.log("list \(listId): gave up, form on screen = \(hasFormAppeared)")
        return hasFormAppeared
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

    /// Closes the sheet and checks the places in `scope` for the chosen party size, day and window.
    func search(listId: String, scope: TableSearchScope) {
        guard canSearch else { return }
        isFormPresented = false
        run(listId: listId, scope: scope)
    }

    /// Repeats the last search (used by the error state's retry).
    func retry(listId: String) {
        guard selection.window.isValid else { return }
        run(listId: listId, scope: scope)
    }

    /// Starts a search, cancelling any in flight; shows a fresh cached result at once, then streams the real one.
    private func run(listId: String, scope: TableSearchScope) {
        searchTask?.cancel()
        let token = UUID()
        searchToken = token
        self.scope = scope
        let request = TableAvailabilityRequest.make(partySize: partySize, date: selection.date, window: selection.window, calendar: calendar)
        let chunks = TableSearchPlanner.chunks(scope.placeIds)
        let key = TableSearchKey(listId: listId, request: request, scope: scope)
        searchKey = key
        let cached = cache.value(for: key)
        accumulator = TableSearchAccumulator(total: scope.placeIds.count, chunkCount: chunks.count, stale: cached?.places ?? [])
        guard !chunks.isEmpty else {
            publish(request: request)
            return
        }
        if cached != nil { publish(request: request) } else { state = .loading }
        searchTask = Task { [weak self, service] in
            await self?.stream(chunks: chunks, listId: listId, request: request, token: token, service: service)
        }
    }

    /// Checks the chunks with a few requests in flight at once, publishing after each one returns.
    private func stream(chunks: [[String]], listId: String, request: TableAvailabilityRequest,
                        token: UUID, service: TableAvailabilityFetching) async {
        await withTaskGroup(of: ChunkOutcome.self) { group in
            var next = 0
            while next < min(TableSearchPlanner.maxConcurrentChunks, chunks.count) {
                let chunk = chunks[next]
                group.addTask { await Self.fetch(chunk: chunk, listId: listId, request: request, service: service) }
                next += 1
            }
            while let outcome = await group.next() {
                guard token == searchToken, !Task.isCancelled else {
                    group.cancelAll()
                    return
                }
                if apply(outcome, request: request) == .stop {
                    group.cancelAll()
                    return
                }
                if next < chunks.count {
                    let chunk = chunks[next]
                    group.addTask { await Self.fetch(chunk: chunk, listId: listId, request: request, service: service) }
                    next += 1
                }
            }
        }
        guard token == searchToken, !Task.isCancelled else { return }
        finish(request: request)
    }

    /// One chunk's request; never throws, so a failing chunk cannot end the search.
    private nonisolated static func fetch(chunk: [String], listId: String, request: TableAvailabilityRequest,
                                          service: TableAvailabilityFetching) async -> ChunkOutcome {
        do {
            let response = try await service.search(listId: listId, request: request.restricted(to: chunk))
            return ChunkOutcome(chunk: chunk, result: .success(response))
        } catch let error as TableAvailabilityError {
            return ChunkOutcome(chunk: chunk, result: .failure(error))
        } catch {
            return ChunkOutcome(chunk: chunk, result: .failure(.failed))
        }
    }

    /// A chunk and what came back for it.
    private struct ChunkOutcome {
        let chunk: [String]
        let result: Result<TableAvailabilityResponse, TableAvailabilityError>
    }

    /// Whether the search should go on after a chunk.
    private enum Flow { case proceed, stop }

    /// Folds a chunk into the results and publishes them; an unavailable backend ends the search.
    private func apply(_ outcome: ChunkOutcome, request: TableAvailabilityRequest) -> Flow {
        switch outcome.result {
        case .success(let response):
            accumulator.applySuccess(chunk: outcome.chunk, response: response)
        case .failure(.unavailable):
            searchToken = UUID()
            isOffered = false
            state = .idle
            return .stop
        case .failure:
            accumulator.applyFailure(chunk: outcome.chunk)
        }
        if !accumulator.isComplete { publish(request: request) }
        return .proceed
    }

    /// Shows what has been found so far.
    private func publish(request: TableAvailabilityRequest) {
        state = .results(Results(
            request: request,
            withTables: accumulator.withTables,
            checkedOnProvider: accumulator.checkedOnProvider,
            processed: accumulator.processedPlaces,
            total: accumulator.total,
            providerName: accumulator.providerName ?? "Resy",
            failedChunks: accumulator.failedChunks,
            isComplete: accumulator.isComplete || accumulator.total == 0
        ))
    }

    /// Publishes the final results (or the error state) and remembers clean searches for five minutes.
    private func finish(request: TableAvailabilityRequest) {
        if accumulator.allFailed || accumulator.everyPlaceErrored {
            state = .failed
            return
        }
        publish(request: request)
        guard accumulator.failedChunks == 0, let searchKey else { return }
        cache.store(CachedTableSearch(places: accumulator.displayed, checked: accumulator.checkedOnProvider,
                                      total: accumulator.total, providerName: accumulator.providerName ?? "Resy"), for: searchKey)
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
