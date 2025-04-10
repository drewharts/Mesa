import Foundation
import SwiftUI

class NotificationViewModel: ObservableObject {
    @Published var notifications: [loc.Notification] = []
    @Published var unreadCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var error: Error?
    
    private let firestoreService: FirestoreService
    private var userId: String
    
    init(userId: String, firestoreService: FirestoreService = FirestoreService()) {
        self.userId = userId
        self.firestoreService = firestoreService
    }
    
    func loadNotifications() {
        isLoading = true
        error = nil
        
        firestoreService.fetchNotifications(userId: userId) { [weak self] (notifications: [loc.Notification]?, error: Error?) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.error = error
                    return
                }
                
                self.notifications = notifications ?? []
                self.updateUnreadCount()
            }
        }
    }
    
    func markAsRead(notificationId: String) {
        firestoreService.markNotificationAsRead(notificationId: notificationId) { [weak self] (result: Result<Void, Error>) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    if let index = self.notifications.firstIndex(where: { $0.id == notificationId }) {
                        var updatedNotification = self.notifications[index]
                        updatedNotification.isRead = true
                        self.notifications[index] = updatedNotification
                        self.updateUnreadCount()
                    }
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
    
    func markAllAsRead() {
        firestoreService.markAllNotificationsAsRead(userId: userId) { [weak self] (result: Result<Void, Error>) in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.notifications = self.notifications.map { notification in
                        var updatedNotification = notification
                        updatedNotification.isRead = true
                        return updatedNotification
                    }
                    self.updateUnreadCount()
                case .failure(let error):
                    self.error = error
                }
            }
        }
    }
    
    private func updateUnreadCount() {
        unreadCount = notifications.filter { !$0.isRead }.count
    }
    
    func formattedTimestamp(for notification: loc.Notification) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: notification.timestamp, to: now)
        
        if let minutes = components.minute, minutes < 60 && (components.hour ?? 0) == 0 && (components.day ?? 0) == 0 {
            return minutes == 0 ? "Just now" : "\(minutes)m"
        } else if let hours = components.hour, hours < 24 && (components.day ?? 0) == 0 {
            return "\(hours)h"
        } else if let days = components.day {
            return "\(days)d"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none
            return formatter.string(from: notification.timestamp)
        }
    }
} 