//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var userSession: UserSession

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("FAVORITES")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)

            if let placeListViewModels = userSession.profileViewModel?.placeListViewModels,
               !placeListViewModels.isEmpty {
                HStack {
                    ForEach(placeListViewModels, id: \.placeList.id) { listVM in
                        NavigationLink(destination: PlaceListView(placeList: listVM.placeList)) {
                                // Placeholder for list image
                            Rectangle()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.gray)
                                .cornerRadius(8)
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
    }
}

#Preview {
    ProfileFavoriteListView()
}
