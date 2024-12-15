//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI

struct ProfileViewListsView: View {
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LISTS")
                .font(.headline)
                .padding(.horizontal)

            if let placeLists = userSession.profileViewModel?.data.placeLists, !placeLists.isEmpty {
                ScrollView {
                    ForEach(placeLists) { list in
                        NavigationLink(destination: PlaceListView(placeList: list)) {
                            HStack {
                                Rectangle() // Placeholder for list image
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(list.name)
                                        .font(.body)
                                    Text("\(list.places.count) Places")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        }
                    }
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}
