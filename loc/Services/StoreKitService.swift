import Foundation
import StoreKit

/// Manages StoreKit 2 product loading, purchasing, and transaction observation.
@MainActor
class StoreKitService: ObservableObject {
    static let shared = StoreKitService()

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseState: PurchaseState = .idle

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        case success
        case failed(String)

        static func == (lhs: PurchaseState, rhs: PurchaseState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.purchasing, .purchasing), (.success, .success):
                return true
            case let (.failed(a), .failed(b)):
                return a == b
            default:
                return false
            }
        }
    }

    private var transactionListenerTask: Task<Void, Never>?

    private init() {}

    /// Loads all mesa_list_tier_* products from the App Store
    func loadProducts() async {
        do {
            let storeProducts = try await Product.products(for: PriceTier.allProductIds)
            products = storeProducts.sorted { $0.price < $1.price }
        } catch {
            print("[StoreKitService] Failed to load products: \(error)")
        }
    }

    /// Finds the loaded Product matching a PriceTier
    func product(for tier: PriceTier) -> Product? {
        products.first { $0.id == tier.storeKitProductId }
    }

    /// Purchases a specific product, returns the verified Transaction
    func purchase(product: Product) async throws -> Transaction {
        purchaseState = .purchasing

        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            purchaseState = .failed(error.localizedDescription)
            throw error
        }

        switch result {
        case .success(let verification):
            let transaction = try checkVerification(verification)
            await transaction.finish()
            purchaseState = .success
            return transaction

        case .userCancelled:
            purchaseState = .idle
            throw PurchaseError.cancelled

        case .pending:
            purchaseState = .idle
            throw PurchaseError.pending

        @unknown default:
            purchaseState = .failed("Unknown purchase result")
            throw PurchaseError.unknown
        }
    }

    /// Starts listening for transaction updates (refunds, ask-to-buy approvals)
    func startTransactionListener(onRevocation: @escaping (UInt64) -> Void) {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                do {
                    let transaction = try await MainActor.run {
                        try self.checkVerification(result)
                    }
                    if transaction.revocationDate != nil {
                        onRevocation(transaction.id)
                    }
                    await transaction.finish()
                } catch {
                    print("[StoreKitService] Transaction update verification failed: \(error)")
                }
            }
        }
    }

    /// Resets purchase state back to idle
    func resetPurchaseState() {
        purchaseState = .idle
    }

    // MARK: - Private

    /// Verifies a StoreKit verification result
    private func checkVerification(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .unverified(_, let error):
            throw PurchaseError.verificationFailed(error.localizedDescription)
        case .verified(let transaction):
            return transaction
        }
    }
}

// MARK: - Purchase Errors

enum PurchaseError: LocalizedError {
    case cancelled
    case pending
    case unknown
    case verificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .cancelled: return "Purchase was cancelled"
        case .pending: return "Purchase is pending approval"
        case .unknown: return "An unknown error occurred"
        case .verificationFailed(let reason): return "Verification failed: \(reason)"
        }
    }
}
