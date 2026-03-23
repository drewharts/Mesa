import SwiftUI

/// Dashboard showing a creator's earnings from paid list sales.
struct CreatorEarningsView: View {
    @StateObject private var viewModel = CreatorEarningsViewModel()

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.listEarnings.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if viewModel.listEarnings.isEmpty {
                emptyState
            } else {
                summarySection
                listBreakdownSection
            }
        }
        .navigationTitle("Earnings")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadEarnings() }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Sections

    /// Overall totals card
    private var summarySection: some View {
        Section {
            VStack(spacing: 8) {
                Text(viewModel.formatCents(viewModel.totalEarningsCents))
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("\(viewModel.totalSales) total sales")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    /// Per-list earnings breakdown
    private var listBreakdownSection: some View {
        Section("By List") {
            ForEach(viewModel.listEarnings, id: \.list_id) { earning in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(earning.list_name)
                            .font(.body)
                            .fontWeight(.medium)

                        Text("\(earning.list_sales) sales")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(viewModel.formatCents(earning.list_earnings_cents))
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            }
        }
    }

    /// Empty state when no paid lists exist
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dollarsign.circle")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No earnings yet")
                .font(.headline)

            Text("Set a price on your lists to start earning from your curated places.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .listRowSeparator(.hidden)
    }
}
