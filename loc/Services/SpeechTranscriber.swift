//
//  SpeechTranscriber.swift
//  loc
//
//  Live speech-to-text over AVAudioEngine + SFSpeechRecognizer (on-device when supported)
//

import Foundation
import AVFoundation
import Speech

/// Streams microphone audio into SFSpeechRecognizer and reports partial transcripts and input levels.
final class SpeechTranscriber {
    enum PermissionResult { case granted, denied, unavailable }

    /// Called on the main thread with the best transcript so far.
    var onTranscript: ((String) -> Void)?
    /// Called on the main thread with a normalized 0...1 input level.
    var onLevel: ((Float) -> Void)?
    /// Called on the main thread once with the final transcript after `stop()`, or on failure.
    var onFinished: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer()
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latest = ""
    private var didFinish = false

    /// Requests microphone and speech-recognition permission, prompting on first use.
    static func requestPermissions() async -> PermissionResult {
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return .denied }
        let mic = await AVAudioApplication.requestRecordPermission()
        return mic ? .granted : .denied
    }

    /// Begins capturing audio and recognizing speech; throws if the recognizer or audio engine is unavailable.
    func start() throws {
        guard let recognizer, recognizer.isAvailable else { throw TranscriberError.unavailable }
        latest = ""
        didFinish = false

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        self.request = request

        installTap(feeding: request)
        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            self?.handle(result: result, error: error)
        }
    }

    /// Stops capturing audio and lets the recognizer deliver its final transcript via `onFinished`.
    func stop() {
        teardownAudio()
        request?.endAudio()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.finish()
        }
    }

    /// Stops everything immediately without reporting a result.
    func cancel() {
        didFinish = true
        teardownAudio()
        task?.cancel()
        task = nil
        request = nil
    }

    // MARK: - Private

    /// Installs the input tap that feeds the recognition request and publishes levels.
    private func installTap(feeding request: SFSpeechAudioBufferRecognitionRequest) {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            request.append(buffer)
            let level = SpeechTranscriber.normalizedLevel(of: buffer)
            DispatchQueue.main.async { self?.onLevel?(level) }
        }
    }

    /// Computes a smoothed 0...1 loudness value from an audio buffer's RMS.
    private static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let rms = (sum / Float(count)).squareRoot()
        let db = 20 * log10(max(rms, 0.000_01))
        return min(max((db + 50) / 50, 0), 1)
    }

    /// Handles recognizer callbacks, tracking the latest transcript and finishing on a final result or error.
    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didFinish else { return }
            if let result {
                self.latest = result.bestTranscription.formattedString
                self.onTranscript?(self.latest)
                if result.isFinal { self.finish() }
            } else if error != nil {
                self.finish()
            }
        }
    }

    /// Reports the final transcript exactly once and releases the recognition task.
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        task?.cancel()
        task = nil
        request = nil
        onFinished?(latest)
    }

    /// Stops the audio engine, removes the tap, and releases the audio session.
    private func teardownAudio() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    enum TranscriberError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Speech recognition isn't available right now." }
    }
}
