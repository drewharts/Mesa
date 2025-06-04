//
//  ProfileListDescription.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ProfileListDescription: View {
    @State var list: PlaceList
    @State private var showingPlacesPopup = false
    @EnvironmentObject var profile: ProfileViewModel
    @Binding var placeColors: [UUID: Color]
    
    var body: some View {
        Button(action: {
            showingPlacesPopup = true
        }) {
            HStack {
                Text(list.name)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.leading, 20)
                Text("\(profile.userListsPlaces[list.id.uuidString]?.count ?? 0) \(profile.userListsPlaces[list.id.uuidString]?.count == 1 ? "place" : "places")")
                    .font(.caption)
                    .foregroundStyle(.black)
            }
        }
        .sheet(isPresented: $showingPlacesPopup) {
            ListPlacesPopupView(list: list, placeColors: $placeColors)
        }
    }
}
