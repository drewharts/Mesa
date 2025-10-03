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
        CardBasedListPreview(
            list: list,
            placeIds: placeIds,
            detailPlaceViewModel: detailPlaceViewModel,
            placeColors: $placeColors,
            isLoading: isLoading
        )
    }
}
