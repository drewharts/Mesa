import SwiftUI
import GooglePlaces

struct SearchResultsView: View {
    let results: [GMSAutocompletePrediction]
    let onSelect: (GMSAutocompletePrediction) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 5) {
                ForEach(results, id: \.placeID) { prediction in
                    Button(action: {
                        onSelect(prediction)
                    }) {
                        VStack(alignment: .center) {
                            Text(prediction.attributedPrimaryText.string)
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)

                            if let secondaryText = prediction.attributedSecondaryText?.string {
                                Text(secondaryText)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }
                        }
                        .padding()
                        .frame(width: UIScreen.main.bounds.width * 0.9, height: 60) // Fixed size for each box
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
    }
}


