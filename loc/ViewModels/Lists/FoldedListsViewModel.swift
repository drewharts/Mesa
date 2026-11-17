//
//  FoldedListsViewModel.swift
//  loc
//
//  Child ViewModel for folding "city + type" lists into the per-city Saved library: runs the detector once
//  per session, remembers the result on this device (FoldedListsStore), and drives the one-time banner,
//  Undo and "Show folded lists". Hides lists only; nothing is deleted or written to the backend.
//

import Foundation

@MainActor
final class FoldedListsViewModel: ObservableObject {
    @Published private(set) var foldedIds: Set<String> = []
    /// When on, folded lists are shown again in the lists UI.
    @Published var showFolded = false
    /// Number of lists folded just now; non-nil while the one-time banner is up.
    @Published private(set) var bannerCount: Int?

    private var store: FoldedListsStore?
    private var activeUserId: String?
    private var lastFolded: [String] = []
    private var isDetecting = false
    private var hasDetected = false

    // MARK: - Derived

    var foldedCount: Int { foldedIds.count }

    var bannerTitle: String {
        let n = bannerCount ?? 0
        return "Folded \(n) \(n == 1 ? "list" : "lists") into your cities"
    }

    var toggleTitle: String { showFolded ? "Hide folded lists" : "Show folded lists (\(foldedCount))" }

    // MARK: - Setup

    /// Loads the saved folded ids for this user; switching users clears the previous user's state.
    func configure(userId: String?) {
        guard let userId, !userId.isEmpty else { return }
        guard activeUserId != userId.lowercased() else { return }
        activeUserId = userId.lowercased()
        store = FoldedListsStore(userId: userId)
        foldedIds = store?.foldedIds ?? []
        bannerCount = nil
        showFolded = false
        hasDetected = false
    }

    /// Clears in-memory state on logout (the saved folded ids stay on the device, keyed by user).
    func reset() {
        activeUserId = nil
        store = nil
        foldedIds = []
        showFolded = false
        bannerCount = nil
        lastFolded = []
        hasDetected = false
    }

    // MARK: - Detection

    /// Looks for city/type lists the Saved library fully covers and folds them; runs once per session.
    /// Any failed read (places, list contents, sharing) ends the pass without folding anything.
    func detectIfNeeded(userId: String, lists: [LightweightPlaceList]) async {
        configure(userId: userId)
        guard SavedLibraryGate.isEnabled, !isDetecting, !hasDetected, !lists.isEmpty, let store else { return }
        isDetecting = true
        defer { isDetecting = false }
        store.prune(keeping: Set(lists.map { $0.list_id.lowercased() }))
        foldedIds = store.foldedIds
        let skipped = store.foldedIds.union(store.declinedIds)
        let candidates = lists.filter { !skipped.contains($0.list_id.lowercased()) && Self.mayFold($0) }
        guard !candidates.isEmpty else { hasDetected = true; return }
        guard let ids = await foldableIds(userId: userId, candidates: candidates) else { return }
        hasDetected = true
        apply(store.fold(ids))
    }

    /// Reads sharing, list contents and the library, then returns the ids the detector folds. Nil on any failure.
    private func foldableIds(userId: String, candidates: [LightweightPlaceList]) async -> [String]? {
        do {
            let shared = try await CollaborationService.shared.fetchCollaborativeOwnedLists(userId: userId)
            let sharedIds = Set(shared.map { $0.listId.lowercased() })
            let open = candidates.filter { !sharedIds.contains($0.list_id.lowercased()) }
            guard !open.isEmpty else { return [] }
            let memberships = try await SavedLibraryDataSource.fetchListMemberships(listIds: open.map(\.list_id))
            let inputs = try await SavedLibraryDataSource.fetchInputs(userId: userId)
            let library = await Task.detached(priority: .utility) { SavedLibraryBuilder.build(inputs, userLocation: nil) }.value
            let inputsForDetector = open.map { Self.candidate(from: $0, placeIds: memberships[$0.list_id.lowercased()] ?? []) }
            return CityListFoldDetector.foldedIds(inputsForDetector, library: library)
        } catch {
            return nil
        }
    }

    /// Cheap pre-check so lists that can never fold (public, shared, paid, empty) cost no extra reads.
    private static func mayFold(_ list: LightweightPlaceList) -> Bool {
        !list.is_public && !list.isCollaborative && !list.isPaid && list.place_count > 0
    }

    /// Maps a list's metadata plus its place ids into what the detector needs.
    private static func candidate(from list: LightweightPlaceList, placeIds: Set<String>) -> FoldCandidateList {
        FoldCandidateList(
            id: list.list_id, name: list.name, isPublic: list.is_public,
            isCollaborative: list.isCollaborative, isPaid: list.isPaid, placeIds: placeIds
        )
    }

    /// Publishes newly folded ids and raises the one-time banner when something folded.
    private func apply(_ newlyFolded: [String]) {
        foldedIds = store?.foldedIds ?? foldedIds
        guard !newlyFolded.isEmpty else { return }
        lastFolded = newlyFolded
        bannerCount = newlyFolded.count
    }

    // MARK: - Actions

    /// Brings back the lists folded by the banner's pass and closes the banner.
    func undoBanner() {
        store?.restore(lastFolded)
        foldedIds = store?.foldedIds ?? []
        lastFolded = []
        bannerCount = nil
    }

    /// Closes the banner and keeps the lists folded.
    func dismissBanner() {
        bannerCount = nil
    }

    /// Shows or hides folded lists in the lists UI.
    func toggleShowFolded() {
        showFolded.toggle()
    }

    /// Brings every folded list back and stops hiding them.
    func restoreAll() {
        store?.restore(Array(foldedIds))
        foldedIds = store?.foldedIds ?? []
        showFolded = false
        bannerCount = nil
    }
}
