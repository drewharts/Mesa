//
//  ReviewSummarizer.swift
//  loc
//
//  On-device review summarization via Apple FoundationModels (iOS 26+); no network or API key
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Turns a spoken transcript into a concise first-person review, entirely on device.
enum ReviewSummarizer {
    /// Whether the on-device language model can be used on this device and OS version.
    static var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// Returns a 2–4 sentence summary of the transcript, or nil if the model is unavailable or fails.
    static func summarize(transcript: String, placeName: String) async -> String? {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), isAvailable {
            return await generate(transcript: transcript, placeName: placeName)
        }
        #endif
        return nil
    }

    /// Lightly cleans a raw transcript: collapses whitespace, capitalizes, and ensures end punctuation.
    static func cleaned(_ transcript: String) -> String {
        let collapsed = transcript.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard let first = collapsed.first else { return "" }
        var text = first.uppercased() + collapsed.dropFirst()
        if let last = text.last, !".!?".contains(last) { text += "." }
        return text
    }

    #if canImport(FoundationModels)
    /// Runs the language model with strict no-invention instructions and returns trimmed output.
    @available(iOS 26, *)
    private static func generate(transcript: String, placeName: String) async -> String? {
        let instructions = """
        You rewrite a spoken restaurant or place experience into a concise written review. \
        Write in first person, 2 to 4 sentences, plain text. Keep specifics the speaker mentioned \
        such as dishes, atmosphere, service, and price. Never add facts, opinions, or details that \
        were not said. Do not use emoji, hashtags, or quotation marks. Output only the review.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let prompt = "Place: \(placeName)\nWhat I said: \(transcript)"
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }
    #endif
}
