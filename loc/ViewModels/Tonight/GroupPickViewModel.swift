//
//  GroupPickViewModel.swift
//  loc
//
//  Drives a group pick: loads it (joining the caller), one-tap yes/no votes,
//  and polls until the server auto-decides the winner (everyone voted or the
//  timer ran out), then shows the result automatically.
//

import Foundation

@MainActor
final class GroupPickViewModel: ObservableObject {
    @Published private(set) var pick: GroupPick?
    @Published private(set) var places: [String: DetailPlace] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    let pickId: String
    private let groupPickService: GroupPickService
    private let tonightService: TonightService
    private var pollTask: Task<Void, Never>?
    private var reportedDecision = false
    static let pollInterval: UInt64 = 6_000_000_000

    init(pickId: String, groupPickService: GroupPickService = .shared, tonightService: TonightService = .shared) {
        self.pickId = pickId
        self.groupPickService = groupPickService
        self.tonightService = tonightService
    }

    // MARK: - Derived

    /// Place ids in the order they were suggested.
    var placeIds: [String] { pick?.placeIds ?? [] }

    /// Returns the loaded details for a place id, if available.
    func place(for placeId: String) -> DetailPlace? {
        places[placeId.lowercased()]
    }

    /// The decided winner's details, once the pick is decided.
    var winner: DetailPlace? {
        guard let id = pick?.decidedPlaceId else { return nil }
        return place(for: id)
    }

    /// Status line under the title, e.g. "3 people in · decides by 8:45 PM".
    var statusText: String {
        guard let pick else { return "" }
        let people = "\(pick.memberCount) \(pick.memberCount == 1 ? "person" : "people") in"
        if pick.isDecided { return "Decided · \(people)" }
        guard let decideAt = pick.decideAt else { return people }
        return "\(people) · decides by \(decideAt.formatted(date: .omitted, time: .shortened))"
    }

    // MARK: - Lifecycle

    /// Loads the pick and its places, then keeps it fresh until decided.
    func start() async {
        await refresh()
        if let pick, places.isEmpty {
            places = await tonightService.fetchDetails(placeIds: pick.placeIds)
        }
        isLoading = false
        startPolling()
    }

    /// Stops background refreshes (call when the sheet disappears).
    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Fetches the latest pick state from the server.
    func refresh() async {
        do {
            apply(try await groupPickService.fetchPick(id: pickId))
            errorMessage = nil
        } catch {
            if pick == nil {
                errorMessage = (error as? GroupPickError)?.errorDescription ?? "Couldn't load this group pick. Update Mesa or try again in a bit."
            }
        }
    }

    /// Polls every few seconds while the pick is undecided so results appear automatically.
    private func startPolling() {
        stop()
        guard pick?.isDecided == false else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.pollInterval)
                guard let self, !Task.isCancelled else { return }
                await self.refresh()
                if self.pick?.isDecided == true { return }
            }
        }
    }

    // MARK: - Voting

    /// Records a one-tap yes/no vote on a place.
    func vote(placeId: String, yes: Bool) async {
        guard let pick, !pick.isDecided else { return }
        do {
            apply(try await groupPickService.vote(pickId: pickId, placeId: placeId, yes: yes))
            Analytics.track(.groupPickVoted, ["vote": yes ? "yes" : "no"])
        } catch {
            errorMessage = "Your vote didn't go through. Try again."
        }
    }

    /// Stores new state and reports the decision once.
    private func apply(_ newPick: GroupPick) {
        pick = newPick
        if newPick.isDecided && !reportedDecision {
            reportedDecision = true
            Analytics.track(.groupPickDecided, ["members": newPick.memberCount])
            stop()
        }
    }
}
