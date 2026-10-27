//
//  GroupPickViewModel.swift
//  loc
//
//  Drives a group pick: loads it (joining the caller), one-tap yes/no votes,
//  and polls until the server decides (everyone voted, a clear winner, or the
//  timer ran out), then shows the result. Also owns the "more options" flows:
//  swap in the next best saved places, add one of your own, invite friends.
//  The sub-screens (add a place, invite) render inside the same sheet.
//

import Foundation
import CoreLocation

@MainActor
final class GroupPickViewModel: ObservableObject {
    /// Which screen the single group-pick sheet is showing.
    enum Mode { case vote, addPlace, invite }

    @Published private(set) var pick: GroupPick?
    @Published private(set) var places: [String: DetailPlace] = [:]
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var notice: String?
    @Published private(set) var isWorking = false
    @Published var mode: Mode = .vote

    // Add a place
    @Published var searchText = ""
    @Published private(set) var isLoadingSaved = false

    // Invite
    @Published private(set) var friends: [TonightFriend] = []
    @Published private(set) var inviteSelection: Set<String> = []

    let pickId: String
    private let userId: String?
    private let locationManager: LocationManager?
    private let groupPickService: GroupPickService
    private let tonightService: TonightService
    private var pollTask: Task<Void, Never>?
    private var reportedDecision = false
    private var reportedResultView = false
    private var firstLoadWasDecided = false
    private var candidates: [TonightCandidate] = []
    private var candidateDetails: [String: DetailPlace] = [:]
    private var friendNames: [String: String] = [:]
    private var candidatesLoaded = false
    static let pollInterval: UInt64 = 6_000_000_000
    /// Places a pick can hold (matches the server limit).
    static let maxPlaces = 10

    init(
        pickId: String,
        userId: String? = nil,
        locationManager: LocationManager? = nil,
        groupPickService: GroupPickService = .shared,
        tonightService: TonightService = .shared
    ) {
        self.pickId = pickId
        self.userId = userId
        self.locationManager = locationManager
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

    /// The decided winner's details, once the pick is decided with a winner.
    var winner: DetailPlace? {
        guard let id = pick?.decidedPlaceId else { return nil }
        return place(for: id)
    }

    /// The current user's id, used to tell "you" apart from the others.
    var currentUserId: String? { userId }

    /// True when the pick can still take more places.
    var canAddMore: Bool { (pick?.placeIds.count ?? 0) < Self.maxPlaces }

    /// Status line under the title, e.g. "3 people in · decides by 8:45 PM".
    var statusText: String {
        guard let pick else { return "" }
        let people = "\(pick.memberCount) \(pick.memberCount == 1 ? "person" : "people") in"
        if pick.isDecided { return "Decided · \(people)" }
        guard let decideAt = pick.decideAt else { return people }
        return "\(people) · decides by \(decideAt.formatted(date: .omitted, time: .shortened))"
    }

    /// Who the vote is waiting on, e.g. "Waiting on Grace" or "Your vote is needed".
    var waitingText: String? {
        guard let pick, !pick.isDecided else { return nil }
        if !pick.hasVotedOnAll(userId: userId) { return "Tap 👍 or 👎 on each place" }
        // The members strip already says who it's waiting on.
        if !pick.members.isEmpty { return nil }
        let pending = pick.pendingMembers(excluding: userId)
        guard !pending.isEmpty else { return "You've voted. Waiting for the others." }
        let names = pending.map(\.displayName)
        switch names.count {
        case 1: return "You've voted. Waiting on \(names[0])."
        case 2: return "You've voted. Waiting on \(names[0]) and \(names[1])."
        default: return "You've voted. Waiting on \(names[0]) and \(names.count - 1) others."
        }
    }

    /// One line explaining how the result was reached.
    var decisionNote: String? {
        guard let pick, pick.isDecided else { return nil }
        let yes = pick.decidedPlaceId.map { pick.tally(for: $0).yes } ?? 0
        let total = max(pick.memberCount, 1)
        switch pick.outcome {
        case .noMatch:
            return "Nobody said yes to any of these."
        case .tieBreak:
            return "Tied at \(yes) yes, so we went with the best-ranked pick."
        default:
            switch pick.decidedReason {
            case "timeout": return "Time ran out. \(yes) of \(total) said yes."
            case "unanimous": return "Everyone said yes."
            default: return "\(yes) of \(total) said yes."
            }
        }
    }

    // MARK: - Lifecycle

    /// Loads the pick and its places, then keeps it fresh until decided.
    func start() async {
        await refresh()
        firstLoadWasDecided = pick?.isDecided == true
        isLoading = false
        reportResultViewedIfNeeded()
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
            await loadMissingPlaces()
        } catch {
            if pick == nil {
                errorMessage = (error as? GroupPickError)?.errorDescription ?? "Couldn't load this group pick. Update Mesa or try again in a bit."
            }
        }
    }

    /// Refreshes now and resumes polling (call when the app returns to the foreground).
    func resume() async {
        await refresh()
        reportResultViewedIfNeeded()
        startPolling()
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
                self.reportResultViewedIfNeeded()
                if self.pick?.isDecided == true { return }
            }
        }
    }

    private func loadMissingPlaces() async {
        guard let pick else { return }
        let missing = pick.placeIds.filter { places[$0.lowercased()] == nil }
        guard !missing.isEmpty else { return }
        let fetched = await tonightService.fetchDetails(placeIds: missing)
        places.merge(fetched) { current, _ in current }
    }

    // MARK: - Voting

    /// Records a one-tap yes/no vote on a place.
    func vote(placeId: String, yes: Bool) async {
        guard let pick, !pick.isDecided else { return }
        do {
            apply(try await groupPickService.vote(pickId: pickId, placeId: placeId, yes: yes))
            Analytics.track(.groupPickVoted, ["vote": yes ? "yes" : "no"])
            reportResultViewedIfNeeded()
            if self.pick?.isDecided == true { stop() }
        } catch {
            errorMessage = "Your vote didn't go through. Try again."
        }
    }

    /// Stores new state and reports the decision once. A reopened pick (more options after no match) re-arms it.
    private func apply(_ newPick: GroupPick) {
        let wasDecided = pick?.isDecided == true
        pick = newPick
        if wasDecided && !newPick.isDecided {
            reportedDecision = false
            reportedResultView = false
            firstLoadWasDecided = false
        }
        if newPick.isDecided && !reportedDecision {
            reportedDecision = true
            Analytics.track(.groupPickDecided, [
                "members": newPick.memberCount,
                "outcome": newPick.outcome?.rawValue ?? "unknown",
                "reason": newPick.decidedReason ?? "unknown",
                "places": newPick.placeIds.count
            ])
            stop()
        }
    }

    private func reportResultViewedIfNeeded() {
        guard let pick, pick.isDecided, !reportedResultView else { return }
        reportedResultView = true
        Analytics.track(.groupPickResultViewed, [
            "outcome": pick.outcome?.rawValue ?? "unknown",
            "via": firstLoadWasDecided ? "opened_decided" : "live"
        ])
    }

    // MARK: - More options

    /// Adds the next 3 best places from the user's and friends' saves (same ranking as Tonight).
    /// On a no-match pick this reopens the vote.
    func suggestMoreOptions() async {
        guard let pick, !isWorking, canAddMore else { return }
        isWorking = true
        notice = nil
        errorMessage = nil
        defer { isWorking = false }
        await loadCandidatesIfNeeded()

        let vibe = TonightVibe.from(headline: pick.title) ?? .inferred()
        let ranker = TonightRanker(vibe: vibe, origin: locationManager?.currentLocation, currentUserId: userId ?? "", friendNames: friendNames)
        let existing = Set(pick.placeIds.map { $0.lowercased() })
        let room = Self.maxPlaces - pick.placeIds.count
        let next = ranker
            .rank(candidates: candidates, places: candidateDetails, limit: 12)
            .filter { !existing.contains($0.placeId.lowercased()) }
            .prefix(min(3, room))
        guard !next.isEmpty else {
            notice = "No more nearby ideas from your saves. Try adding a place yourself."
            Analytics.track(.groupPickMoreOptions, ["source": "suggest", "added": 0])
            return
        }
        await add(placeIds: next.map(\.placeId), source: "suggest")
    }

    /// Adds one of the user's own (or friends') saved places to the vote.
    func addPlace(placeId: String) async {
        guard !isWorking, canAddMore else { return }
        isWorking = true
        notice = nil
        errorMessage = nil
        defer { isWorking = false }
        await add(placeIds: [placeId], source: "search")
    }

    private func add(placeIds: [String], source: String) async {
        do {
            let before = pick?.placeIds.count ?? 0
            apply(try await groupPickService.addPlaces(pickId: pickId, placeIds: placeIds))
            await loadMissingPlaces()
            let added = (pick?.placeIds.count ?? 0) - before
            if added > 0 {
                mode = .vote
                notice = added == 1 ? "Added to the vote." : "Added \(added) more options."
                Analytics.track(source == "search" ? .groupPickPlaceAdded : .groupPickMoreOptions, ["source": source, "added": added])
                if pick?.isDecided == false { startPolling() }
            } else {
                notice = "That place can't be added."
                Analytics.track(.groupPickActionFailed, ["action": "add_places", "reason": "none_added"])
            }
        } catch {
            handleActionError(error, action: "add_places")
        }
    }

    // MARK: - Add a place (search saves)

    /// Opens the add-a-place screen and loads the user's and friends' saves.
    func beginAddPlace() async {
        mode = .addPlace
        searchText = ""
        await loadCandidatesIfNeeded()
    }

    /// Saved places that can be added: not already in the pick, filtered by the search text.
    var addablePlaces: [(placeId: String, place: DetailPlace)] {
        let existing = Set((pick?.placeIds ?? []).map { $0.lowercased() })
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let origin = locationManager?.currentLocation
        let rows: [(placeId: String, place: DetailPlace, saves: Int)] = candidates.compactMap { (candidate) -> (placeId: String, place: DetailPlace, saves: Int)? in
            let key = candidate.placeId.lowercased()
            guard !existing.contains(key), let place = candidateDetails[key] else { return nil }
            if !query.isEmpty {
                let haystack = ([place.name, place.address ?? ""] + (place.categories ?? [])).joined(separator: " ").lowercased()
                guard haystack.contains(query) else { return nil }
            }
            return (placeId: candidate.placeId, place: place, saves: candidate.saverIds.count)
        }
        let sorted = rows.sorted { lhs, rhs in
            if let origin, let a = lhs.place.coordinate, let b = rhs.place.coordinate {
                let da = origin.distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude))
                let db = origin.distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
                if da != db { return da < db }
            }
            if lhs.saves != rhs.saves { return lhs.saves > rhs.saves }
            return lhs.place.name < rhs.place.name
        }
        return sorted.prefix(40).map { (placeId: $0.placeId, place: $0.place) }
    }

    // MARK: - Invite

    /// Opens the invite screen and loads the people the user follows.
    func beginInvite() async {
        mode = .invite
        inviteSelection = []
        await loadCandidatesIfNeeded(friendsOnly: true)
    }

    /// Friends who are not in the pick yet.
    var invitableFriends: [TonightFriend] {
        let members = Set((pick?.members ?? []).map { $0.userId.lowercased() })
        return friends
            .filter { !members.contains($0.id.lowercased()) }
            .sorted { $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending }
    }

    func toggleInvite(_ friendId: String) {
        if inviteSelection.contains(friendId) { inviteSelection.remove(friendId) } else { inviteSelection.insert(friendId) }
    }

    /// Adds the selected friends to the pick; each gets a push.
    func sendInvites() async {
        guard !inviteSelection.isEmpty, !isWorking else { return }
        isWorking = true
        notice = nil
        errorMessage = nil
        defer { isWorking = false }
        let ids = Array(inviteSelection)
        do {
            let before = pick?.memberCount ?? 0
            apply(try await groupPickService.invite(pickId: pickId, userIds: ids))
            let added = max((pick?.memberCount ?? 0) - before, 0)
            inviteSelection = []
            mode = .vote
            notice = added > 0 ? "Invited \(added) \(added == 1 ? "person" : "people")." : "They're already in or can't be invited."
            Analytics.track(.groupPickInvited, ["requested": ids.count, "added": added])
        } catch {
            handleActionError(error, action: "invite")
        }
    }

    // MARK: - Shared loading

    /// Loads friends and (unless `friendsOnly`) saves with details once per sheet.
    private func loadCandidatesIfNeeded(friendsOnly: Bool = false) async {
        guard let userId else { return }
        if friends.isEmpty {
            friends = await tonightService.fetchFriends(userId: userId)
            friendNames = Dictionary(friends.map { ($0.id.lowercased(), $0.firstName) }, uniquingKeysWith: { a, _ in a })
        }
        guard !friendsOnly, !candidatesLoaded else { return }
        isLoadingSaved = true
        defer { isLoadingSaved = false }
        candidates = await tonightService.fetchCandidates(userId: userId, friendIds: friends.map(\.id))
        candidateDetails = await tonightService.fetchDetails(for: candidates, near: locationManager?.currentLocation)
        candidatesLoaded = true
    }

    /// Shows a calm message; older servers without the 20261027 functions land here.
    private func handleActionError(_ error: Error, action: String) {
        let text = String(describing: error).lowercased()
        let missing = text.contains("could not find the function") || text.contains("pgrst202") || text.contains("does not exist")
        errorMessage = missing
            ? "That isn't available yet. It'll work after the next Mesa update on the server."
            : "Couldn't do that. Try again."
        Analytics.track(.groupPickActionFailed, ["action": action, "reason": missing ? "not_deployed" : "error"])
    }
}
