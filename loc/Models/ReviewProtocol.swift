protocol ReviewProtocol: Codable {
    var id: String { get }
    var userId: String { get }
    var profilePhotoUrl: String { get }
    var userFirstName: String { get }
    var userLastName: String { get }
    var placeId: String { get }
    var placeName: String { get }
    var reviewText: String { get }
    var timestamp: Date { get }
    var images: [String] { get set }
    var likes: Int { get set }
    var type: ReviewType { get }
}