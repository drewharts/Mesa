//
//  CitySaveBannerViewModel.swift
//  loc
//
//  ViewModel for the "Added to {City}" banner shown after a one-tap save or an import.
//  Single Responsibility: runs the city-list save and owns the banner text and its auto-dismiss.
//

import Foundation

@MainActor
final class CitySaveBannerViewModel: ObservableObject {
    @Published private(set) var message: String?
    /// True when the banner reports a failed save (shown without the "Change" action).
    @Published private(set) var isError = false
    /// The places the banner refers to; "Change" targets exactly these.
    private(set) var savedPlaces: [DetailPlace] = []
    private var dismissTask: Task<Void, Never>?

    /// Saves the places into their city lists and shows the banner. Returns true if any place was saved.
    @discardableResult
    func save(_ places: [DetailPlace], profile: ProfileViewModel, userSession: UserSession) async -> Bool {
        let fresh = ImportAutoSave.placesToSave(from: places, alreadySaved: [])
        guard !fresh.isEmpty else { return false }
        let summary = await CitySaveViewModel(profile: profile, userSession: userSession).save(fresh)
        guard let text = summary.message else {
            show("Couldn't save. Try again.", isError: true)
            return false
        }
        savedPlaces = fresh
        show(text, isError: false)
        return true
    }

    /// Hides the banner.
    func dismiss() {
        dismissTask?.cancel()
        message = nil
    }

    /// Shows banner text and hides it automatically after a few seconds.
    private func show(_ text: String, isError: Bool) {
        self.isError = isError
        message = text
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.message = nil
        }
    }
}
