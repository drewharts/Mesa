import Foundation

/// Represents available pricing tiers for paid place lists.
/// Each tier maps to a StoreKit consumable IAP product.
enum PriceTier: String, Codable, CaseIterable {
    case tier099 = "tier_099"
    case tier199 = "tier_199"
    case tier499 = "tier_499"
    case tier999 = "tier_999"
    case tier1999 = "tier_1999"

    /// User-facing price string (e.g. "$0.99")
    var displayPrice: String {
        switch self {
        case .tier099: return "$0.99"
        case .tier199: return "$1.99"
        case .tier499: return "$4.99"
        case .tier999: return "$9.99"
        case .tier1999: return "$19.99"
        }
    }

    /// Price in cents for database storage
    var priceInCents: Int {
        switch self {
        case .tier099: return 99
        case .tier199: return 199
        case .tier499: return 499
        case .tier999: return 999
        case .tier1999: return 1999
        }
    }

    /// StoreKit product identifier registered in App Store Connect
    var storeKitProductId: String {
        "mesa_list_\(rawValue)"
    }

    /// All StoreKit product IDs for loading products
    static var allProductIds: Set<String> {
        Set(allCases.map(\.storeKitProductId))
    }

    /// Finds the tier matching a StoreKit product ID
    static func from(productId: String) -> PriceTier? {
        allCases.first { $0.storeKitProductId == productId }
    }
}
