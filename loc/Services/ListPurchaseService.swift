import Foundation

/// Coordinates the full purchase flow: StoreKit payment, verification, and database recording.
@MainActor
class ListPurchaseService {
    static let shared = ListPurchaseService()

    private let supabase = SupabaseManager.shared
    private let storeKitService = StoreKitService.shared

    private init() {}

    /// Executes the full purchase flow: StoreKit purchase -> verify -> record in DB
    func purchaseList(listId: String, priceTier: PriceTier, userId: String) async throws {
        guard let product = storeKitService.product(for: priceTier) else {
            throw ListPurchaseError.productNotFound
        }

        let transaction = try await storeKitService.purchase(product: product)

        try await recordPurchase(
            userId: userId,
            listId: listId,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            priceTier: priceTier
        )
    }

    /// Checks if user has purchased a specific list (or is owner/collaborator)
    func hasUserPurchasedList(userId: String, listId: String) async throws -> Bool {
        let result: Bool = try await supabase.client
            .rpc("check_list_purchase", params: [
                "p_user_id": userId,
                "p_list_id": listId
            ])
            .execute()
            .value

        return result
    }

    /// Fetches all list IDs the user has purchased
    func fetchPurchasedListIds(userId: String) async throws -> Set<String> {
        struct PurchaseRecord: Decodable {
            let list_id: String
        }

        let records: [PurchaseRecord] = try await supabase.client
            .from("list_purchases")
            .select("list_id")
            .eq("user_id", value: userId)
            .execute()
            .value

        return Set(records.map(\.list_id))
    }

    /// Fetches creator earnings summary for the earnings dashboard
    func fetchCreatorEarnings(creatorId: String) async throws -> [CreatorListEarning] {
        let earnings: [CreatorListEarning] = try await supabase.client
            .rpc("get_creator_earnings_summary", params: [
                "p_creator_id": creatorId
            ])
            .execute()
            .value

        return earnings
    }

    /// Removes a purchase record (used when Apple reports a refund/revocation)
    func removePurchase(transactionId: UInt64) async {
        do {
            try await supabase.client
                .from("list_purchases")
                .delete()
                .eq("transaction_id", value: String(transactionId))
                .execute()
        } catch {
            print("[ListPurchaseService] Failed to remove revoked purchase: \(error)")
        }
    }

    // MARK: - Private

    /// Records a verified purchase in the database
    private func recordPurchase(
        userId: String,
        listId: String,
        transactionId: String,
        originalTransactionId: String,
        priceTier: PriceTier
    ) async throws {
        struct Params: Encodable {
            let p_user_id: String
            let p_list_id: String
            let p_transaction_id: String
            let p_original_transaction_id: String
            let p_price_tier: String
            let p_price_cents: Int
        }

        try await supabase.client
            .rpc("record_list_purchase", params: Params(
                p_user_id: userId,
                p_list_id: listId,
                p_transaction_id: transactionId,
                p_original_transaction_id: originalTransactionId,
                p_price_tier: priceTier.rawValue,
                p_price_cents: priceTier.priceInCents
            ))
            .execute()
    }
}

// MARK: - Supporting Types

/// Represents earnings data for a single list from the creator earnings RPC
struct CreatorListEarning: Codable {
    let total_sales: Int
    let total_earnings_cents: Int
    let list_id: String
    let list_name: String
    let list_sales: Int
    let list_earnings_cents: Int
}

enum ListPurchaseError: LocalizedError {
    case productNotFound

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "Product not found in App Store"
        }
    }
}
