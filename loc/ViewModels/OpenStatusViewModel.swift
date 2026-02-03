//
//  OpenStatusViewModel.swift
//  loc
//
//  Created by Cursor on 12/14/24.
//  ViewModel for managing place open/closed status display.
//  Single Responsibility: Receives place data and provides status for UI.
//

import Foundation
import Combine

@MainActor
class OpenStatusViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var status: OpenStatus = .unknown
    @Published private(set) var displayText: String = ""
    @Published private(set) var isOpen: Bool = false
    @Published private(set) var shouldDisplay: Bool = false

    // MARK: - Private Properties

    private var currentPlace: DetailPlace?
    private var refreshTimer: Timer?

    // MARK: - Initialization

    init() {}

    deinit {
        refreshTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Sets the current place and updates the open status
    func setPlace(_ place: DetailPlace?) {
        currentPlace = place
        updateStatus(for: place)
    }
    
    // MARK: - Status Updates
    
    private func updateStatus(for place: DetailPlace?) {
        // Cancel existing timer
        refreshTimer?.invalidate()
        
        guard let place = place else {
            clearStatus()
            return
        }
        
        let newStatus = OpenStatusService.getStatus(for: place)
        applyStatus(newStatus)
        
        // Schedule refresh for time-sensitive statuses
        scheduleRefreshIfNeeded(for: newStatus)
    }
    
    private func applyStatus(_ newStatus: OpenStatus) {
        status = newStatus
        displayText = newStatus.displayText
        isOpen = newStatus.isOpen
        shouldDisplay = newStatus.shouldDisplay
    }
    
    private func clearStatus() {
        status = .unknown
        displayText = ""
        isOpen = false
        shouldDisplay = false
    }
    
    /// Schedules automatic refresh for time-sensitive statuses (closing/opening soon)
    private func scheduleRefreshIfNeeded(for status: OpenStatus) {
        switch status {
        case .closingSoon, .openingSoon:
            // Refresh every minute for time-sensitive statuses
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self,
                          let place = self.currentPlace else { return }
                    self.updateStatus(for: place)
                }
            }
        default:
            break
        }
    }

    // MARK: - Manual Refresh

    /// Force refresh the open status (useful for pull-to-refresh scenarios)
    func refresh() {
        updateStatus(for: currentPlace)
    }
}
