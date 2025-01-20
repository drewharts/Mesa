//
//  AddFavoritesSearchResultsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/20/25.
//

import SwiftUI
import GooglePlaces

struct AddFavoritesSearchResultsView: View {
    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = SearchViewModel()
    
    @State private var lastTappedPlaceID: String?
    @State private var showAlert: Bool = false

    var body: some View {
        if !viewModel.searchResults.isEmpty {
            List(viewModel.searchResults, id: \.self) { prediction in
                SearchResultRow(prediction: prediction, isHighlighted: prediction.placeID == lastTappedPlaceID)
                    .onTapGesture {
                        handleTapGesture(for: prediction)
                    }
            }
            .listStyle(.plain)
            .alert("You can only add up to 4 favorites.", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            }
        }
    }

    // Extracted the content of each row into a separate view
    private struct SearchResultRow: View {
        let prediction: GMSAutocompletePrediction
        let isHighlighted: Bool

        var body: some View {
            HStack {
                Text(prediction.attributedPrimaryText.string)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 6)
            .background(isHighlighted ? Color.blue.opacity(0.2) : Color.clear)
        }
    }

    // Extracted the tap gesture logic into a separate function
    private func handleTapGesture(for prediction: GMSAutocompletePrediction) {
        guard let profileViewModel = userSession.profileViewModel else { return }

        if profileViewModel.favoritePlaces.count >= 4 {
            showAlert = true
            return
        }

        addAndHighlightFavorite(prediction: prediction, profileViewModel: profileViewModel)
    }

    // Extracted the logic for adding and highlighting the favorite
    private func addAndHighlightFavorite(prediction: GMSAutocompletePrediction, profileViewModel: ProfileViewModel) {
        profileViewModel.addFavoritePlace(prediction: prediction)
        lastTappedPlaceID = prediction.placeID

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                lastTappedPlaceID = nil
            }
        }
    }
}
