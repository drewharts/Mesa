import Foundation

struct Notification: Codable, Identifiable {
    let id: String // UUID for the notification
    let userId: String // ID of the user who should receive the notification
    let type: NotificationType // Type of notification
    let reviewId: String // ID of the review
    let commentId: String? // ID of the comment (if applicable)
    let placeId: String // ID of the place
    let placeName: String // Name of the place
    let actorId: String // ID of the user who triggered the notification
    let actorFirstName: String // First name of the actor
    let actorLastName: String // Last name of the actor
    let actorProfilePhotoUrl: String // Profile photo URL of the actor
    let timestamp: Date // When the notification was created
    var isRead: Bool // Whether the notification has been read
}

enum NotificationType: String, Codable {
    case commentOnReview = "commentOnReview"
    // Add more types as needed
} 