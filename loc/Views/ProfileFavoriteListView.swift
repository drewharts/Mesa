//
//  ProfileFavoriteListView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/22/24.
//

import SwiftUI

struct ProfileFavoriteListView: View {
    @EnvironmentObject var userSession: UserSession
    
    // State to control showing the search sheet
    @State private var showSearch = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            
            // 1) Wrap Text in a Button to trigger search popup
            Button(action: {
                showSearch = true
            }) {
                Text("FAVORITES")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 20)
                    // You can customize button style here
            }
            .buttonStyle(.plain)

            if let profileFavoritePlaces = userSession.profileViewModel?.favoritePlaces,
               !profileFavoritePlaces.isEmpty {
                
                // If you want indices
                HStack {
                    ForEach(profileFavoritePlaces) { place in
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        // 3) Present a sheet for searching & adding restaurants
        .sheet(isPresented: $showSearch) {
            AddFavoritesView()
        }
    }
}

#Preview {
}
