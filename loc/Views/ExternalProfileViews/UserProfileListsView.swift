//
//  UserProfileListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//


import SwiftUI

struct UserProfileListsView: View {
    @ObservedObject var viewModel: UserProfileViewModel
    var placeLists: [PlaceList]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20) // Match Favorites
                .foregroundStyle(.black)

            if placeLists.isEmpty {
                Text("No lists available")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            } else {
                UserProfileListViewJustLists(viewModel: viewModel, placeLists: placeLists)
            }
        }
    }
}
