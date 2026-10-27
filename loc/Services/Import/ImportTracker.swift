//
//  ImportTracker.swift
//  loc
//
//  Keeps video imports alive after the progress sheet is closed.
//
//  Processing already runs server-side (Mesa-backend `import_jobs`), so "continue in the background"
//  only needs the app to find out when a job is done:
//   1. Primary: the backend sends an `import_complete` push (see send-push-notification edge function).
//   2. Fallback: pending job ids are persisted; while the app is open the tracker polls them, and on
//      launch / foreground it resumes them. If the user left, a local notification (or, with
//      notifications off, the result sheet itself) tells them it is ready.
//  Tapping either notification opens `.importJob(jobId:)`.
//

import Foundation
import UIKit
import UserNotifications

@MainActor
final class ImportTracker {
    static let shared = ImportTracker()

    struct PendingImport: Codable, Equatable {
        let jobId: String
        let contentUrl: String?
        let startedAt: Date
    }

    private let defaultsKey = "ImportTracker.pending.v1"
    /// Ignore jobs older than this (the backend gives up long before).
    private let maxJobAge: TimeInterval = 30 * 60
    private let pollInterval: UInt64 = 3_000_000_000
    private let contentService = ExternalContentService()
    private var watchers: [String: Task<Void, Never>] = [:]

    private init() {}

    // MARK: - Pending persistence

    private var pending: [PendingImport] {
        get {
            guard let data = UserDefaults.standard.data(forKey: defaultsKey),
                  let items = try? JSONDecoder().decode([PendingImport].self, from: data) else { return [] }
            return items
        }
        set {
            UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: defaultsKey)
        }
    }

    /// Remembers a running job so it can be resumed after the app is closed.
    func track(jobId: String, contentUrl: String?) {
        guard !pending.contains(where: { $0.jobId == jobId }) else { return }
        pending.append(PendingImport(jobId: jobId, contentUrl: contentUrl, startedAt: Date()))
    }

    /// The user has seen the result (sheet reached a terminal state) — nothing left to track.
    func finished(jobId: String) {
        pending.removeAll { $0.jobId == jobId }
        watchers[jobId]?.cancel()
        watchers[jobId] = nil
    }

    // MARK: - Watching

    /// The sheet was closed while the job was still running: keep following it here.
    func handOff(jobId: String) {
        guard pending.contains(where: { $0.jobId == jobId }) else { return }
        Analytics.track(.importBackgrounded)
        watch(jobId)
    }

    /// Resumes every pending job (call on launch and whenever the app becomes active).
    func resumePending() {
        let now = Date()
        pending.removeAll { now.timeIntervalSince($0.startedAt) > maxJobAge }
        for item in pending { watch(item.jobId) }
    }

    private func watch(_ jobId: String) {
        guard watchers[jobId] == nil else { return }
        watchers[jobId] = Task { [weak self] in
            await self?.poll(jobId)
        }
    }

    private func poll(_ jobId: String) async {
        defer { watchers[jobId] = nil }
        // Keep polling for the short grace period iOS gives us after the user leaves the app.
        let bgTask = BackgroundTaskBox()
        bgTask.id = UIApplication.shared.beginBackgroundTask(withName: "import-\(jobId)") {
            UIApplication.shared.endBackgroundTask(bgTask.id)
            bgTask.id = .invalid
        }
        defer { if bgTask.id != .invalid { UIApplication.shared.endBackgroundTask(bgTask.id) } }

        while !Task.isCancelled {
            guard let item = pending.first(where: { $0.jobId == jobId }),
                  Date().timeIntervalSince(item.startedAt) <= maxJobAge else {
                pending.removeAll { $0.jobId == jobId }
                return
            }
            if case .success(let job) = await contentService.fetchImportJob(id: jobId), job.status.isTerminal {
                await complete(job)
                return
            }
            try? await Task.sleep(nanoseconds: pollInterval)
        }
    }

    // MARK: - Completion

    private func complete(_ job: ImportJob) async {
        // The user is looking at the import sheet — it already shows the result.
        if isShowingImportSheet {
            pending.removeAll { $0.jobId == job.id }
            return
        }
        // Not in the foreground: the backend push covers this. Keep the job pending so the
        // next foreground resume can still surface it if the push never arrived.
        guard UIApplication.shared.applicationState == .active else { return }

        pending.removeAll { $0.jobId == job.id }
        // A push for this job is already sitting in Notification Center — don't double up.
        if await hasDeliveredNotification(jobId: job.id) { return }

        let names = job.savedPlaces.map { $0.name }
        switch await NotificationPermissionService.shared.authorizationStatus() {
        case .authorized, .provisional, .ephemeral:
            await postLocalNotification(jobId: job.id, names: names, placeId: job.savedPlaces.first?.id.uuidString)
        default:
            // Notifications are off: open the result directly rather than leaving it unseen.
            if PresentationService.shared.activeSheet == nil {
                openResult(jobId: job.id)
            }
        }
    }

    private var isShowingImportSheet: Bool {
        switch PresentationService.shared.activeSheet {
        case .importProgress, .importJob: return true
        default: return false
        }
    }

    /// Whether the push/local notification for this job is still in Notification Center.
    private func hasDeliveredNotification(jobId: String) async -> Bool {
        let delivered = await UNUserNotificationCenter.current().deliveredNotifications()
        return delivered.contains { ($0.request.content.userInfo["jobId"] as? String) == jobId }
    }

    private func postLocalNotification(jobId: String, names: [String], placeId: String?) async {
        let content = UNMutableNotificationContent()
        switch names.count {
        case 0:
            content.title = "Couldn't find a place"
            content.body = "We couldn't find a place in that video. Tap to add one yourself."
        case 1:
            content.title = "Found \(names[0])"
            content.body = "Saved from your video. Tap to add it to a list."
        default:
            content.title = "Found \(names.count) places"
            content.body = "\(names[0]) and \(names.count - 1) more from your video. Tap to review."
        }
        content.sound = .default
        var info: [String: Any] = ["type": "import_complete", "jobId": jobId]
        if let placeId { info["placeId"] = placeId }
        content.userInfo = info
        let request = UNNotificationRequest(identifier: "import-\(jobId)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
        Analytics.track(.importNotificationShown, ["kind": "local", "places": names.count])
    }

    // MARK: - Notification handling (called from AppDelegate)

    /// Tap on an `import_complete` notification (push or local): open the result.
    func openResult(jobId: String) {
        pending.removeAll { $0.jobId == jobId }
        PresentationService.shared.present(.importJob(jobId: jobId))
    }

    /// Whether a notification that arrives while the app is open should be hidden because the
    /// user is already looking at an import sheet.
    func shouldSuppressForegroundNotification(userInfo: [AnyHashable: Any]) -> Bool {
        guard (userInfo["type"] as? String) == "import_complete" else { return false }
        if let jobId = userInfo["jobId"] as? String { pending.removeAll { $0.jobId == jobId } }
        return isShowingImportSheet
    }
}

/// Reference box so the background-task expiration handler can end the task it belongs to.
private final class BackgroundTaskBox: @unchecked Sendable {
    var id: UIBackgroundTaskIdentifier = .invalid
}
