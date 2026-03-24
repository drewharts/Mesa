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
                    PriceTierChipView(
                        tier: tier,
                        isSelected: viewModel.selectedTier == tier,
                        onTap: { viewModel.selectedTier = tier }
                    )
                }
            }
            .padding(.vertical, 4)
        }
    }
}
