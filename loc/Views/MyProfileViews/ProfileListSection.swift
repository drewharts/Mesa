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
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading) {
            ProfileListDescription(list: list, placeColors: $placeColors)
            
            if isLoading {
                // Show loading skeleton
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 80)
                            .cornerRadius(8)
                    }
                }
                .padding(.leading, 20)
            } else if let placeIds = placeIds, !placeIds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    MyProfileHorizontalListPlaces(listId: list.id, placeColors: $placeColors)
                }
            } else {
                Text("No places in this list")
                    .foregroundColor(.gray)
                    .padding(.leading, 20)
            }
        }
    }
}
