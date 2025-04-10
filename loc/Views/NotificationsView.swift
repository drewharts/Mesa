import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel: NotificationViewModel
    @Environment(\.dismiss) private var dismiss
    
    init(userId: String) {
        _viewModel = StateObject(wrappedValue: NotificationViewModel(userId: userId))
    }
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                        Text("No notifications yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        ForEach(viewModel.notifications) { notification in
                            NotificationRow(notification: notification, viewModel: viewModel)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                if !viewModel.notifications.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Mark all as read") {
                            viewModel.markAllAsRead()
                        }
                    }
                }
            }
        }
        .onAppear {
            viewModel.loadNotifications()
        }
    }
}

struct NotificationRow: View {
    let notification: loc.Notification
    let viewModel: NotificationViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile photo
            AsyncImage(url: URL(string: notification.actorProfilePhotoUrl)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            // Notification content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(notification.actorFirstName) \(notification.actorLastName)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    switch notification.type {
                    case .commentOnReview:
                        Text("commented on your review")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Text(notification.placeName)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(viewModel.formattedTimestamp(for: notification))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if !notification.isRead {
                viewModel.markAsRead(notificationId: notification.id)
            }
            // TODO: Navigate to the review
        }
    }
}

#Preview {
    NotificationsView(userId: "preview_user_id")
} 