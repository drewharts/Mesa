//
//  ImportProgressViewModel.swift
//  loc
//
//  ViewModel for the live import progress sheet.
//  Single Responsibility: Starts an async import job (or attaches to an existing one, e.g. from a
//  notification tap) and polls it until it finishes. Closing the sheet hands a running job to
//  ImportTracker so the import still completes and the user gets notified.
//

import Foundation

@MainActor
class ImportProgressViewModel: ObservableObject {
    /// The video URL. For a job opened by id it is filled in once the job is fetched.
    @Published private(set) var contentUrl: String
    /// Set when attaching to an already-running/finished job instead of starting a new import.
    private let existingJobId: String?
    private var jobId: String?

    @Published private(set) var statusText: String = ImportJobStatus.queued.displayText
    @Published private(set) var places: [ImportJobPlace] = []
    @Published private(set) var isFinished: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedPlaces: [DetailPlace] = []
    /// Whether the user can leave the app and still be told when the import is done.
    @Published private(set) var notificationsEnabled: Bool = false

    private let contentService: ExternalContentService
    private var pollTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 1_500_000_000
    private let maxPollDuration: TimeInterval = 240

    /// Initializes with the shared content URL to import.
    init(contentUrl: String, contentService: ExternalContentService = ExternalContentService()) {
        self.contentUrl = contentUrl
        self.existingJobId = nil
        self.contentService = contentService
    }

    /// Attaches to an existing import job (opened from a notification or on resume).
    init(jobId: String, contentService: ExternalContentService = ExternalContentService()) {
        self.contentUrl = ""
        self.existingJobId = jobId
        self.jobId = jobId
        self.contentService = contentService
    }

    /// Starts the import once; safe to call repeatedly from onAppear.
    func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            await self?.run()
        }
    }

    /// Cancels polling (e.g. when the sheet is dismissed).
    func stop() {
        pollTask?.cancel()
        // Still running? Let the tracker keep following it so the user gets notified when it's done.
        if let jobId, !isFinished {
            ImportTracker.shared.handOff(jobId: jobId)
        }
    }

    /// Number of places saved so far.
    var savedCount: Int {
        places.filter { $0.status == .saved || $0.status == .duplicate }.count
    }

    /// Starts the job, then polls until it reaches a terminal state.
    private func run() async {
        if let existingJobId {
            await poll(jobId: existingJobId)
            return
        }
        Analytics.track(.importStarted, ["url_host": URL(string: contentUrl)?.host ?? ""])
        switch await contentService.startImport(contentUrl) {
        case .failure(let error):
            finish(error: error.localizedDescription)
        case .success(.places(let detailPlaces)):
            applySyncResult(detailPlaces)
        case .success(.job(let jobId)):
            self.jobId = jobId
            // Remember the job so it survives closing the sheet / the app, then ask for notification
            // permission now — the user has just started an import they can walk away from.
            ImportTracker.shared.track(jobId: jobId, contentUrl: contentUrl)
            Task { [weak self] in
                let allowed = await NotificationPermissionService.shared.requestIfNeeded(context: "import_started")
                self?.notificationsEnabled = allowed
            }
            await poll(jobId: jobId)
        }
    }

    /// Polls the job every pollInterval until done, failed, or timed out.
    private func poll(jobId: String) async {
        let startedAt = Date()
        var consecutiveFailures = 0
        while !Task.isCancelled {
            switch await contentService.fetchImportJob(id: jobId) {
            case .success(let job):
                consecutiveFailures = 0
                apply(job)
                if job.status.isTerminal { return }
            case .failure:
                consecutiveFailures += 1
                if consecutiveFailures >= 5 {
                    ImportTracker.shared.finished(jobId: jobId)
                    finish(error: "We couldn't load this import.")
                    return
                }
            }
            if Date().timeIntervalSince(startedAt) > maxPollDuration {
                // The server may still be working: keep following it in the background.
                ImportTracker.shared.handOff(jobId: jobId)
                finish(error: "The import is taking too long. We'll let you know when it's done.")
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }

    /// Applies a job snapshot to the published state.
    private func apply(_ job: ImportJob) {
        if contentUrl.isEmpty, let url = job.url { contentUrl = url }
        if job.status.isTerminal { ImportTracker.shared.finished(jobId: job.id) }
        places = applyCorrections(to: job.places)
        savedPlaces = places.filter { $0.status == .saved }.compactMap { $0.place }
        statusText = job.status.displayText
        if job.status == .saving, job.totalFound > 0 {
            statusText = "Adding places… \(savedCount)/\(job.totalFound)"
        }
        if job.status == .failed {
            finish(error: job.error ?? "Something went wrong while importing.")
        } else if job.status == .done {
            if job.places.isEmpty {
                finish(error: "We couldn't find any places in this video.")
            } else {
                // Detection status only: nothing is in a list until the user saves.
                statusText = "Found \(savedCount) place\(savedCount == 1 ? "" : "s")"
                isFinished = true
                Analytics.track(.importFinished, ["success": true, "places_found": job.totalFound, "places_saved": savedCount])
            }
        }
    }

    /// Handles a synchronous fallback response from older backends.
    private func applySyncResult(_ detailPlaces: [DetailPlace]) {
        guard !detailPlaces.isEmpty else {
            finish(error: "We couldn't find any places in this video.")
            return
        }
        savedPlaces = detailPlaces
        places = detailPlaces.enumerated().map {
            ImportJobPlace(index: $0.offset, name: $0.element.name, status: .saved,
                           placeId: $0.element.id.uuidString, place: $0.element)
        }
        statusText = "Added \(detailPlaces.count) place\(detailPlaces.count == 1 ? "" : "s")"
        isFinished = true
        Analytics.track(.importFinished, ["success": true, "places_found": detailPlaces.count, "places_saved": detailPlaces.count])
    }

    /// Marks the import as finished with an error.
    private func finish(error: String) {
        errorMessage = error
        statusText = ImportJobStatus.failed.displayText
        isFinished = true
        Analytics.track(.importFinished, ["success": false])
    }

    // MARK: - Actions

    /// Adds a place the user picked by hand (already linked to this video via external_places).
    func appendManualPlace(_ place: DetailPlace) {
        guard !savedPlaces.contains(where: { $0.id == place.id }) else { return }
        savedPlaces.append(place)
        let nextIndex = (places.map { $0.index }.max() ?? -1) + 1
        places.append(ImportJobPlace(index: nextIndex, name: place.name, status: .saved,
                                     placeId: place.id.uuidString, place: place))
        errorMessage = nil
        statusText = "Added \(savedPlaces.count) place\(savedPlaces.count == 1 ? "" : "s")"
        isFinished = true
    }

    // MARK: - Wrong-place corrections

    /// Place ids the user removed as wrong, and wrong id -> corrected place. Re-applied on every poll.
    private var removedPlaceIds = Set<String>()
    private var replacements: [String: DetailPlace] = [:]

    private func applyCorrections(to jobPlaces: [ImportJobPlace]) -> [ImportJobPlace] {
        jobPlaces.compactMap { item in
            guard let id = item.place?.id.uuidString.lowercased() else { return item }
            if removedPlaceIds.contains(id) { return nil }
            if let fixed = replacements[id] {
                return ImportJobPlace(index: item.index, name: fixed.name, status: .saved,
                                      placeId: fixed.id.uuidString, place: fixed)
            }
            return item
        }
    }

    /// Replaces a wrongly detected place with the one the user picked. The new place is already
    /// linked to this video (PlaceCorrectionSheet, resolved id); this drops the wrong link.
    func replacePlace(_ wrong: DetailPlace, with correct: DetailPlace) async {
        guard !PlaceIdGuard.isPlaceholder(correct.id.uuidString) else { return }
        let wrongKey = wrong.id.uuidString.lowercased()
        replacements[wrongKey] = correct
        if savedPlaces.contains(where: { $0.id == correct.id }) {
            // Already in the import: just drop the wrong one.
            removedPlaceIds.insert(wrongKey)
        }
        places = applyCorrections(to: places)
        savedPlaces = dedup(places.filter { $0.status == .saved }.compactMap { $0.place })
        await unlinkFromVideo(wrong)
        Analytics.track(.importPlaceCorrected, ["action": "replace"])
    }

    /// Removes a wrongly detected place from this import and unlinks it from the video.
    func removePlace(_ wrong: DetailPlace) async {
        removedPlaceIds.insert(wrong.id.uuidString.lowercased())
        places = applyCorrections(to: places)
        savedPlaces = places.filter { $0.status == .saved }.compactMap { $0.place }
        if places.isEmpty {
            errorMessage = "No places left. Search for the right one below."
        }
        statusText = "\(savedPlaces.count) place\(savedPlaces.count == 1 ? "" : "s") found"
        await unlinkFromVideo(wrong)
        Analytics.track(.importPlaceCorrected, ["action": "remove"])
    }

    private func dedup(_ list: [DetailPlace]) -> [DetailPlace] {
        var seen = Set<UUID>()
        return list.filter { seen.insert($0.id).inserted }
    }

    /// Deletes the external_places row linking the wrong place to this video (best effort).
    private func unlinkFromVideo(_ place: DetailPlace) async {
        guard !contentUrl.isEmpty, !PlaceIdGuard.isPlaceholder(place.id.uuidString),
              let userId = SupabaseAuthService.shared.currentUserId else { return }
        do {
            try await ExternalPlaceService.shared.deleteVideoFromPlace(
                placeId: place.id.uuidString, videoUrl: contentUrl, userId: userId)
        } catch {
            print("ImportProgress: couldn't unlink wrong place: \(error.localizedDescription)")
        }
    }

    /// Opens the existing confirmation prompt for a single saved place.
    func openConfirmation(for place: DetailPlace, detailPlaceVM: DetailPlaceViewModel) {
        detailPlaceVM.places[place.id.uuidString] = place
        PresentationService.shared.present(
            .importPlaceConfirmation(placeId: place.id.uuidString, contentUrl: contentUrl)
        )
    }

    /// Hands all saved places to the existing Detected Places screen (view + add to lists, incl. add all).
    func reviewAllPlaces(detailPlaceVM: DetailPlaceViewModel) {
        for place in savedPlaces {
            detailPlaceVM.places[place.id.uuidString] = place
        }
        detailPlaceVM.calculateAnnotationPlaces()
        PresentationService.shared.dismiss()
        let places = savedPlaces
        let url = contentUrl
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            NotificationCenter.default.post(
                name: NSNotification.Name("ExternalContentMultiplePlacesFound"),
                object: nil,
                userInfo: ["places": places, "tikTokUrl": url]
            )
        }
    }

    /// Closes the sheet.
    func dismiss() {
        stop()
        PresentationService.shared.dismiss()
    }
}
