import SwiftUI

/// Overlay shown at the bottom of a paid list's content when the user hasn't purchased.
/// Shows a gradient fade and a call-to-action button to unlock the full list.
struct PaidListTeaserOverlay: View {
    let remainingCount: Int
    let displayPrice: String
    let onUnlockTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Gradient fade effect
            LinearGradient(
                colors: [.clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 60)

            // Call-to-action area
            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                Text("Unlock \(remainingCount) more places")
                    .font(.headline)

                Button(action: onUnlockTapped) {
                    Text("Unlock for \(displayPrice)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
        }
    }
}
