import Foundation

/// Represents a completed purchase of a paid place list.
struct ListPurchase: Codable, Identifiable {
    let id: String
    let user_id: String
    let list_id: String
    let price_tier: String
    let price_cents: Int
    let transaction_id: String
    let original_transaction_id: String?
    let purchased_at: String?
}
