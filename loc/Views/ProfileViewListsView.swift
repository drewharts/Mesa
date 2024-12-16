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

            if let placeListViewModels = userSession.profileViewModel?.placeListViewModels,
               !placeListViewModels.isEmpty {
                ScrollView {
                    ForEach(placeListViewModels, id: \.placeList.id) { listVM in
                        NavigationLink(destination: PlaceListView(placeList: listVM.placeList)) {
                            HStack {
                                // Placeholder for list image
                                Rectangle()
                                    .frame(width: 60, height: 60)
                                    .foregroundColor(.gray)
                                    .cornerRadius(8)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(listVM.placeList.name)
                                        .font(.body)
                                    Text("\(listVM.placeList.places.count) Places")
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
