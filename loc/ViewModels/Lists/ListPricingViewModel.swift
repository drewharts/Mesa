import Foundation

/// Manages the pricing configuration for a place list.
@MainActor
class ListPricingViewModel: ObservableObject {
    @Published var isPaid: Bool
    @Published var selectedTier: PriceTier
    @Published private(set) var isSaving = false
    @Published var errorMessage: String?

    private let listId: String
    private let placeListService = PlaceListService.shared

    init(listId: String, currentPriceTier: String?) {
        self.listId = listId
        if let currentPriceTier, let tier = PriceTier(rawValue: currentPriceTier) {
            self.isPaid = true
            self.selectedTier = tier
        } else {
            self.isPaid = false
            self.selectedTier = .tier199
        }
    }

    /// Saves the pricing setting to the database
    func savePricing() async -> Bool {
        isSaving = true
        errorMessage = nil

        let tier: String? = isPaid ? selectedTier.rawValue : nil

        do {
            try await placeListService.updateListPricing(listId: listId, priceTier: tier)
            isSaving = false
            return true
        } catch {
            errorMessage = "Failed to save pricing"
            isSaving = false
            return false
        }
    }
}
