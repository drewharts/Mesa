import SwiftUI

/// Displays a toggle for paid lists and a horizontal tier selector when enabled.
struct ListPricingPickerView: View {
    @ObservedObject var viewModel: ListPricingViewModel

    var body: some View {
        Toggle("Paid List", isOn: $viewModel.isPaid)
            .disabled(viewModel.isSaving)

        if viewModel.isPaid {
            priceTierPicker
        }
    }

    /// Horizontal row of selectable price tier chips
    private var priceTierPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(PriceTier.allCases, id: \.self) { tier in
                    priceTierChip(tier)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Individual price tier selection chip
    private var priceTierChip: (PriceTier) -> some View {
        { tier in
            Text(tier.displayPrice)
                .font(.subheadline)
                .fontWeight(viewModel.selectedTier == tier ? .semibold : .regular)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(viewModel.selectedTier == tier ? Color.blue : Color(.systemGray6))
                .foregroundStyle(viewModel.selectedTier == tier ? .white : .primary)
                .clipShape(Capsule())
                .onTapGesture {
                    viewModel.selectedTier = tier
                }
        }
    }
}
