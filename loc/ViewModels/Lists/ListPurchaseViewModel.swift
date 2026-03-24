import Foundation

/// Manages the purchase flow for a buyer viewing a paid list.
@MainActor
class ListPurchaseViewModel: ObservableObject {
    @Published var purchaseState: PurchaseState = .idle
    @Published private(set) var hasPurchased: Bool = false

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

    private let listId: String
    private let priceTier: PriceTier
    private let listPurchaseService = ListPurchaseService.shared

    init(listId: String, priceTier: PriceTier) {
        self.listId = listId
        self.priceTier = priceTier
    }

    /// Checks whether the current user has already purchased this list
    func checkPurchaseStatus() async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }
        do {
            hasPurchased = try await listPurchaseService.hasUserPurchasedList(
                userId: userId, listId: listId
            )
        } catch {
            print("[ListPurchaseViewModel] Failed to check purchase status: \(error)")
        }
    }

    /// Triggers the full StoreKit purchase flow and records in DB
    func purchase() async {
        guard let userId = await SupabaseManager.shared.currentUserId else {
            purchaseState = .failed("Not signed in")
            return
        }

        purchaseState = .purchasing

        do {
            try await listPurchaseService.purchaseList(
                listId: listId,
                priceTier: priceTier,
                userId: userId
            )
            purchaseState = .success
            hasPurchased = true
        } catch let purchaseError as PurchaseError {
            if case .cancelled = purchaseError {
                purchaseState = .idle
            } else {
                purchaseState = .failed(purchaseError.localizedDescription)
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }
}
