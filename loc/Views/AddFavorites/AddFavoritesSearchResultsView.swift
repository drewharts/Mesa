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
    @ObservedObject var viewModel: SearchViewModel // Use @ObservedObject to observe the shared viewModel
    
    @Binding var showAlert: Bool // Use Binding to control the alert from parent view
    
    @State private var lastTappedPlaceID: String?
    
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
        } else if !viewModel.searchText.isEmpty {
            // Optionally, show a message when there are no results
            Text("No results found.")
                .foregroundColor(.gray)
                .padding()
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
    
    // Handle tap gesture by adding to favorites
    private func handleTapGesture(for prediction: GMSAutocompletePrediction) {
        guard let profileViewModel = userSession.profileViewModel else { return }

        if profileViewModel.favoritePlaces.count >= 4 {
            showAlert = true
            return
        }

        addAndHighlightFavorite(prediction: prediction, profileViewModel: profileViewModel)
    }
    
    // Add favorite and highlight the selected place
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
