import Foundation

/// Loads and exposes earnings data for the creator earnings dashboard.
@MainActor
class CreatorEarningsViewModel: ObservableObject {
    @Published private(set) var totalEarningsCents: Int = 0
    @Published private(set) var totalSales: Int = 0
    @Published private(set) var listEarnings: [CreatorListEarning] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let listPurchaseService = ListPurchaseService.shared

    /// Loads earnings summary for the current user
    func loadEarnings() async {
        guard let userId = await SupabaseManager.shared.currentUserId else { return }
        isLoading = true

        do {
            let earnings = try await listPurchaseService.fetchCreatorEarnings(creatorId: userId)
            listEarnings = earnings
            if let first = earnings.first {
                totalSales = first.total_sales
                totalEarningsCents = first.total_earnings_cents
            } else {
                totalSales = 0
                totalEarningsCents = 0
            }
        } catch {
            errorMessage = "Failed to load earnings"
        }

        isLoading = false
    }

    /// Formats cents as a dollar string (e.g. 1999 -> "$19.99")
    func formatCents(_ cents: Int) -> String {
        let dollars = Double(cents) / 100.0
        return String(format: "$%.2f", dollars)
    }
}
