//
//  VoiceReviewViewModel.swift
//  loc
//
//  Drives the "talk instead of type" review flow: record, transcribe, summarize, fill the text field
//

import SwiftUI

@MainActor
final class VoiceReviewViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle, recording, summarizing
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var liveTranscript = ""
    @Published private(set) var level: Float = 0
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var permissionDenied = false
    @Published private(set) var errorMessage: String?
    /// True when the field currently holds the full transcript instead of the summary.
    @Published private(set) var usingFullTranscript = false
    @Published private(set) var canUndo = false

    static let maxDuration: TimeInterval = 120

    private let transcriber = SpeechTranscriber()
    private let placeName: () -> String
    private let getText: () -> String
    private let setText: (String) -> Void

    private var baseText = ""
    private var summaryText: String?
    private var fullText = ""
    private var timer: Timer?

    /// Creates the view model with closures to read/write the review text and read the place name.
    init(placeName: @escaping () -> String,
         getText: @escaping () -> String,
         setText: @escaping (String) -> Void) {
        self.placeName = placeName
        self.getText = getText
        self.setText = setText
        transcriber.onTranscript = { [weak self] in self?.liveTranscript = $0 }
        transcriber.onLevel = { [weak self] in self?.level = $0 }
        transcriber.onFinished = { [weak self] in self?.handleFinished(transcript: $0) }
    }

    /// Whether summarization will use the on-device model (otherwise the cleaned transcript is inserted).
    var summarizesWithAI: Bool { ReviewSummarizer.isAvailable }

    /// Whether an AI summary exists that the user can swap with the full transcript.
    var canToggleTranscript: Bool { summaryText != nil }

    /// Elapsed recording time formatted as m:ss.
    var elapsedLabel: String {
        String(format: "%d:%02d", Int(elapsed) / 60, Int(elapsed) % 60)
    }

    /// Starts recording if idle, or stops it if recording.
    func toggle() {
        switch phase {
        case .idle: Task { await begin() }
        case .recording: stop()
        case .summarizing: break
        }
    }

    /// Requests permissions on first use, then starts recording and the max-duration timer.
    private func begin() async {
        errorMessage = nil
        permissionDenied = false
        guard await SpeechTranscriber.requestPermissions() == .granted else {
            permissionDenied = true
            return
        }
        do {
            baseText = getText()
            liveTranscript = ""
            elapsed = 0
            canUndo = false
            usingFullTranscript = false
            try transcriber.start()
            phase = .recording
            startTimer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Stops recording and waits for the final transcript.
    func stop() {
        guard phase == .recording else { return }
        stopTimer()
        level = 0
        transcriber.stop()
    }

    /// Switches the field between the AI summary and the full cleaned transcript.
    func toggleFullTranscript() {
        guard let summaryText else { return }
        usingFullTranscript.toggle()
        setText(compose(usingFullTranscript ? fullText : summaryText))
    }

    /// Restores the review text to what it was before the voice note.
    func undo() {
        setText(baseText)
        canUndo = false
        summaryText = nil
    }

    /// Cancels any in-flight recording without changing the review text.
    func cancel() {
        stopTimer()
        transcriber.cancel()
        phase = .idle
    }

    // MARK: - Private

    /// Summarizes the final transcript (or falls back to the cleaned transcript) and fills the field.
    private func handleFinished(transcript: String) {
        let full = ReviewSummarizer.cleaned(transcript)
        guard !full.isEmpty else {
            phase = .idle
            errorMessage = "Didn't catch anything. Tap the mic and try again."
            return
        }
        fullText = full
        guard ReviewSummarizer.isAvailable else {
            apply(summary: nil, full: full)
            return
        }
        phase = .summarizing
        Task {
            let summary = await ReviewSummarizer.summarize(transcript: transcript, placeName: placeName())
            apply(summary: summary, full: full)
        }
    }

    /// Writes the chosen text into the field and updates undo/toggle state.
    private func apply(summary: String?, full: String) {
        if let summary {
            summaryText = summary
            usingFullTranscript = false
            setText(compose(summary))
        } else {
            summaryText = nil
            usingFullTranscript = true
            setText(compose(full))
        }
        canUndo = true
        phase = .idle
    }

    /// Appends new text to whatever was in the field before recording.
    private func compose(_ addition: String) -> String {
        let base = baseText.trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? addition : base + "\n\n" + addition
    }

    /// Starts a 0.25s timer that tracks elapsed time and auto-stops at the max duration.
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsed += 0.25
                if self.elapsed >= Self.maxDuration { self.stop() }
            }
        }
    }

    /// Invalidates the recording timer.
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}
