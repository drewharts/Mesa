//
//  ImportProgressViewModel.swift
//  loc
//
//  ViewModel for the live import progress sheet.
//  Single Responsibility: Starts an async import job and polls it until it finishes.
//

import Foundation

@MainActor
class ImportProgressViewModel: ObservableObject {
    let contentUrl: String

    @Published private(set) var statusText: String = ImportJobStatus.queued.displayText
    @Published private(set) var places: [ImportJobPlace] = []
    @Published private(set) var isFinished: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var savedPlaces: [DetailPlace] = []

    private let contentService: ExternalContentService
    private var pollTask: Task<Void, Never>?
    private let pollInterval: UInt64 = 1_500_000_000
    private let maxPollDuration: TimeInterval = 240

    /// Initializes with the shared content URL to import.
    init(contentUrl: String, contentService: ExternalContentService = ExternalContentService()) {
        self.contentUrl = contentUrl
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
    }

    /// Number of places saved so far.
    var savedCount: Int {
        places.filter { $0.status == .saved || $0.status == .duplicate }.count
    }

    /// Starts the job, then polls until it reaches a terminal state.
    private func run() async {
        switch await contentService.startImport(contentUrl) {
        case .failure(let error):
            finish(error: error.localizedDescription)
        case .success(.places(let detailPlaces)):
            applySyncResult(detailPlaces)
        case .success(.job(let jobId)):
            await poll(jobId: jobId)
        }
    }

    /// Polls the job every pollInterval until done, failed, or timed out.
    private func poll(jobId: String) async {
        let startedAt = Date()
        while !Task.isCancelled {
            if case .success(let job) = await contentService.fetchImportJob(id: jobId) {
                apply(job)
                if job.status.isTerminal { return }
            }
            if Date().timeIntervalSince(startedAt) > maxPollDuration {
                finish(error: "The import is taking too long. Your places may still appear shortly.")
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }

    /// Applies a job snapshot to the published state.
    private func apply(_ job: ImportJob) {
        places = job.places
        savedPlaces = job.savedPlaces
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
                statusText = "Added \(savedCount) of \(job.totalFound) places"
                isFinished = true
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
    }

    /// Marks the import as finished with an error.
    private func finish(error: String) {
        errorMessage = error
        statusText = ImportJobStatus.failed.displayText
        isFinished = true
    }

    // MARK: - Actions

    /// Opens the existing confirmation prompt for a single saved place.
    func openConfirmation(for place: DetailPlace, detailPlaceVM: DetailPlaceViewModel) {
        detailPlaceVM.places[place.id.uuidString] = place
        PresentationService.shared.present(
            .importPlaceConfirmation(placeId: place.id.uuidString, contentUrl: contentUrl)
        )
    }

    /// Hands all saved places to the existing multi-place selection flow.
    func reviewAllPlaces(detailPlaceVM: DetailPlaceViewModel) {
        if savedPlaces.count == 1, let place = savedPlaces.first {
            openConfirmation(for: place, detailPlaceVM: detailPlaceVM)
            return
        }
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
                userInfo: ["places": places, "contentUrl": url]
            )
        }
    }

    /// Closes the sheet.
    func dismiss() {
        stop()
        PresentationService.shared.dismiss()
    }
}
