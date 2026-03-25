import SwiftUI

/// Displays a selectable price tier chip with active/inactive styling.
struct PriceTierChipView: View {
    let tier: PriceTier
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Text(tier.displayPrice)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
            .onTapGesture(perform: onTap)
    }
}
