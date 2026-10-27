//
//  TonightViewModel.swift
//  loc
//
//  Drives the Tonight sheet: shows 3 picks instantly with no input
//  (current location, vibe inferred from the time of day, all friends'
//  saves), lets the user optionally switch the vibe, and starts a group pick
//  with one tap.
//

import Foundation
import CoreLocation

@MainActor
final class TonightViewModel: ObservableObject {
    enum State: Equatable {
        case loading
        case loaded([TonightPick])
        case empty(String)
    }

    @Published private(set) var state: State = .loading
    @Published private(set) var vibe: TonightVibe = .inferred()
    @Published private(set) var hasLocation = false
    @Published private(set) var isSharing = false
    /// Active and recently decided group picks (empty if the server doesn't have my_group_picks yet).
    @Published private(set) var myPicks: [GroupPickSummary] = []
    /// True when more than one page of picks is available ("More options").
    @Published private(set) var canShowMore = false

    private let userSession: UserSession
    private let locationManager: LocationManager
    private let tonightService: TonightService
    private let groupPickService: GroupPickService
    private let shareService = PlaceShareService()

    private var candidates: [TonightCandidate] = []
    private var details: [String: DetailPlace] = [:]
    private var friendNames: [String: String] = [:]
    private var origin: CLLocation?
    private var hasLoaded = false
    /// Page 0 is the default top 3; later pages are the next best candidates, 3 at a time.
    private var pages: [[TonightPick]] = []
    private var pageIndex = 0

    init(
        userSession: UserSession,
        locationManager: LocationManager,
        tonightService: TonightService = .shared,
        groupPickService: GroupPickService = .shared
    ) {
        self.userSession = userSession
        self.locationManager = locationManager
        self.tonightService = tonightService
        self.groupPickService = groupPickService
    }

    var picks: [TonightPick] {
        if case .loaded(let picks) = state { return picks }
        return []
    }

    // MARK: - Loading

    /// Loads candidates once per sheet presentation and shows the top picks for the inferred vibe.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        Analytics.track(.tonightOpened, ["vibe": vibe.rawValue])
        async let picksLoad: Void = loadMyPicks()
        await load()
        await picksLoad
    }

    /// Loads the user's active/decided group picks for the "Your picks" row. Failure just hides the row.
    func loadMyPicks() async {
        let picks = await groupPickService.fetchMyPicks()
        myPicks = Array(picks.prefix(3))
        if !picks.isEmpty {
            Analytics.track(.tonightPicksRowShown, [
                "count": picks.count,
                "needs_vote": picks.filter(\.needsMyVote).count,
                "decided": picks.filter(\.isDecided).count
            ])
        }
    }

    /// Opens a group pick from the row.
    func openPick(_ summary: GroupPickSummary) {
        Analytics.track(.tonightPicksRowTapped, ["decided": summary.isDecided, "needs_vote": summary.needsMyVote])
        PresentationService.shared.present(.groupPick(pickId: summary.id))
    }

    /// Swaps in the next best 3 places from the same ranked list, wrapping back to the top picks.
    func showMoreOptions() {
        guard pages.count > 1 else { return }
        pageIndex = (pageIndex + 1) % pages.count
        state = .loaded(pages[pageIndex])
        Analytics.track(.tonightMoreOptions, ["page": pageIndex, "vibe": vibe.rawValue])
    }

    /// Fetches saves from the user's circle (no Google calls) and ranks them.
    func load() async {
        guard let userId = userSession.currentUserId else {
            state = .empty("Sign in to see tonight's picks.")
            return
        }
        state = .loading
        origin = await currentLocation()
        hasLocation = origin != nil

        let friends = await tonightService.fetchFriends(userId: userId)
        friendNames = Dictionary(friends.map { ($0.id.lowercased(), $0.firstName) }, uniquingKeysWith: { a, _ in a })
        candidates = await tonightService.fetchCandidates(userId: userId, friendIds: friends.map(\.id))
        details = await tonightService.fetchDetails(for: candidates, near: origin)
        rerank(reportAnalytics: true)
    }

    /// Switches the vibe and re-ranks locally (no network).
    func selectVibe(_ newVibe: TonightVibe) {
        guard newVibe != vibe else { return }
        vibe = newVibe
        guard !candidates.isEmpty else { return }
        rerank(reportAnalytics: true)
    }

    /// Re-ranks the cached candidates for the current vibe and publishes the result.
    private func rerank(reportAnalytics: Bool) {
        guard let userId = userSession.currentUserId else { return }
        let ranker = TonightRanker(vibe: vibe, origin: origin, currentUserId: userId, friendNames: friendNames)
        let picks = ranker.rank(candidates: candidates, places: details)
        // Default stays the top 3; extra pages come from a wider ranking, minus what's already shown.
        let shown = Set(picks.map(\.placeId))
        let extras = ranker.rank(candidates: candidates, places: details, limit: 12).filter { !shown.contains($0.placeId) }
        pages = picks.isEmpty ? [] : [picks] + extras.chunked(into: 3)
        pageIndex = 0
        canShowMore = pages.count > 1
        if picks.isEmpty {
            state = .empty(candidates.isEmpty
                ? "Save a few places (or follow friends) and Mesa will pick for you."
                : "Nothing from your saves fits right now. Try another vibe.")
        } else {
            state = .loaded(picks)
        }
        if reportAnalytics {
            Analytics.track(.tonightResultsShown, [
                "vibe": vibe.rawValue,
                "count": picks.count,
                "candidates": candidates.count,
                "has_location": origin != nil
            ])
        }
    }

    /// Waits briefly for a location fix so picks can be ranked by distance.
    private func currentLocation() async -> CLLocation? {
        locationManager.requestLocationPermission()
        for _ in 0..<12 {
            if let location = locationManager.currentLocation { return location }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return locationManager.currentLocation
    }

    // MARK: - Group pick

    /// Creates a group pick from the current 3 picks, opens the share sheet with the link, and shows the live vote.
    /// Falls back to sharing the places as plain links if group picks are not available on the server yet.
    func startGroupPick() async {
        let picks = self.picks
        guard !picks.isEmpty, !isSharing else { return }
        isSharing = true
        defer { isSharing = false }

        let names = picks.map(\.place.name)
        do {
            let pickId = try await groupPickService.createPick(placeIds: picks.map(\.placeId), title: vibe.headline)
            Analytics.track(.groupPickCreated, ["vibe": vibe.rawValue, "count": picks.count])
            guard let url = groupPickService.shareURL(pickId: pickId) else { return }
            let text = "Where should we go? Tap to vote: \(names.joined(separator: ", "))"
            // Swap to the live vote first so the share sheet sits on top of it, not on the closing Tonight sheet.
            PresentationService.shared.present(.groupPick(pickId: pickId))
            try? await Task.sleep(nanoseconds: 700_000_000)
            shareService.presentShareSheet(with: [text, url])
        } catch {
            print("⚠️ [Tonight] Group pick unavailable, sharing places instead: \(error)")
            let lines = picks.compactMap { pick -> String? in
                guard let url = shareService.generateShareURL(for: pick.place) else { return pick.place.name }
                return "\(pick.place.name): \(url.absoluteString)"
            }
            let text = "Where should we go tonight?\n" + lines.joined(separator: "\n")
            shareService.presentShareSheet(with: [text])
        }
    }
}
