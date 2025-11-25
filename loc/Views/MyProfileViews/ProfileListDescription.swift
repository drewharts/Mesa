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
                
                Text("\(profile.placeListCounts[list.id] ?? 0) \(profile.placeListCounts[list.id] == 1 ? "place" : "places")")
                    .font(.caption)
                    .foregroundStyle(.black)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingPlacesPopup) {
            let lists = profile.userLists
            let initialIndex = lists.firstIndex(where: { $0.id == list.id }) ?? 0
            SwipeableListPopupView(
                lists: lists,
                initialListIndex: initialIndex,
                placeColors: $placeColors
            )
        }
    }
}
