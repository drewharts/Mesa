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
                
                // 1) Use HStack
                HStack {
                    ForEach(placeListViewModels.indices, id: \.self) { index in
                        let listVM = placeListViewModels[index]
                        
                        // 2) Each item goes directly in HStack
                        NavigationLink(
                            destination: PlaceListView(placeList: listVM.placeList)
                        ) {
                            // Placeholder for list image
                            Rectangle()
                                .frame(width: 100, height: 100)
                                .cornerRadius(8)
                        }
                        
                        // 3) Spacer after each item, except the last
                        if index < placeListViewModels.count - 1 {
                            Spacer()
                        }
                    }
                }
                // 4) One horizontal padding to shift entire row
                .padding(.horizontal, 20)
                
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
