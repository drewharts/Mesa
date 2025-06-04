//
//  ProfileListSection.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ProfileListSection: View {
    let list: PlaceList
    let placeIds: [String]?
    let detailPlaceViewModel: DetailPlaceViewModel
    @Binding var placeColors: [UUID: Color]

    var body: some View {
        VStack(alignment: .leading) {
            ProfileListDescription(list: list, placeColors: $placeColors)
            if let _ = placeIds {
                ScrollView(.horizontal, showsIndicators: false) {
                    MyProfileHorizontalListPlaces(listId: list.id, placeColors: $placeColors)
                }
            } else {
                Text("Loading places...")
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}
