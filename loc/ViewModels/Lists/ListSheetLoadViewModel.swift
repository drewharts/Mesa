//
//  ListSheetLoadViewModel.swift
//  loc
//
//  ViewModel that resolves a list for the map list sheet when it is not in the profile cache.
//  Single Responsibility: Fetch one list by id with a bounded wait, exposing loading / failed state.
//

import Foundation

@MainActor
class ListSheetLoadViewModel: ObservableObject {

    /// What the list sheet placeholder should currently show.
    enum State: Equatable {
        case loading
        case failed(message: String)
    }

    @Published private(set) var state: State = .loading

    /// Seconds to wait for the list before showing an error with retry.
    static let timeoutSeconds: TimeInterval = 15

    private let listId: String
    private let fetchList: (String) async throws -> LightweightPlaceList?
    private let onLoaded: (LightweightPlaceList) -> Void
    private let timeout: TimeInterval

    /// Creates a loader for one list; `onLoaded` receives the list so the caller can cache it.
    init(
        listId: String,
        timeout: TimeInterval = ListSheetLoadViewModel.timeoutSeconds,
        fetchList: @escaping (String) async throws -> LightweightPlaceList?,
        onLoaded: @escaping (LightweightPlaceList) -> Void
    ) {
        self.listId = listId
        self.timeout = timeout
        self.fetchList = fetchList
        self.onLoaded = onLoaded
    }

    /// Fetches the list and hands it to `onLoaded`; always ends in success or `.failed` (never stays loading).
    func load() async {
        state = .loading
        do {
            let list = try await fetchWithTimeout()
            if let list {
                onLoaded(list)
            } else {
                state = .failed(message: "This list is no longer available.")
            }
        } catch is CancellationError {
            // The sheet went away mid-fetch; a later appearance calls load() again.
            state = .failed(message: "Loading was interrupted.")
        } catch {
            state = .failed(message: "Couldn't load this list. Check your connection and try again.")
        }
    }

    /// Runs the fetch against a timer so a hung request surfaces as an error instead of spinning.
    private func fetchWithTimeout() async throws -> LightweightPlaceList? {
        let fetch = fetchList
        let id = listId
        let seconds = timeout
        return try await withThrowingTaskGroup(of: LightweightPlaceList?.self) { group in
            group.addTask { try await fetch(id) }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw URLError(.timedOut)
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { return nil }
            return first
        }
    }
}
