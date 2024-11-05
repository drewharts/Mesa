//
//  SearchResultsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//


import SwiftUI
import GooglePlaces

struct SearchResultsView: View {
    let results: [GMSAutocompletePrediction]
    let onSelect: (GMSAutocompletePrediction) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(results, id: \.placeID) { prediction in
                    Button(action: {
                        onSelect(prediction)
                    }) {
                        VStack(alignment: .leading) {
                            Text(prediction.attributedPrimaryText.string)
                                .font(.headline)
                                .foregroundColor(.black)
                            
                            if let secondaryText = prediction.attributedSecondaryText?.string {
                                Text(secondaryText)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                        .padding(.horizontal, 10)
                    }
                }
            }
            .padding(.top, 10)
        }
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal, 20)
    }
}
