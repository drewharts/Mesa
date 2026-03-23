import SwiftUI

/// Sheet shown when a buyer taps "Unlock" on a paid list.
/// Displays list info, price, and a purchase button with loading/success/error states.
struct ListPurchaseSheet: View {
    @ObservedObject var viewModel: ListPurchaseViewModel
    @Environment(\.dismiss) private var dismiss

    let listName: String
    let listImage: String?
    let listDescription: String?
    let placeCount: Int
    let displayPrice: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                listHeader
                Divider()
                listDetails
                Spacer()
                purchaseButton
            }
            .padding()
            .navigationTitle("Unlock List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Subviews

    /// List cover image and name
    private var listHeader: some View {
        VStack(spacing: 12) {
            if let imageUrl = listImage, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Color(.systemGray5)
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(listName)
                .font(.title2)
                .fontWeight(.bold)
        }
    }

    /// Place count and description
    private var listDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("\(placeCount) places", systemImage: "mappin.and.ellipse")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let desc = listDescription, !desc.isEmpty {
                Text(desc)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Purchase button with state handling
    private var purchaseButton: some View {
        Group {
            switch viewModel.purchaseState {
            case .idle:
                Button {
                    Task { await viewModel.purchase() }
                } label: {
                    Text("Purchase for \(displayPrice)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

            case .purchasing:
                ProgressView("Processing...")
                    .frame(maxWidth: .infinity)
                    .padding()

            case .success:
                Label("Purchased!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }

            case .failed(let message):
                VStack(spacing: 8) {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.red)

                    Button("Try Again") {
                        viewModel.purchaseState = .idle
                    }
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }
}
