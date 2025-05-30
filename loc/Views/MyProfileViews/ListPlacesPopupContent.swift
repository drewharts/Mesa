//
//  ListPlacesPopupContent.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ListPlacesPopupContent: View {
    let list: PlaceList
    @Binding var placeColors: [UUID: Color]
    @Binding var showingDeleteConfirmation: Bool
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.gray)
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Text(list.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            Spacer().frame(height: 20)
            ListPlacesPopUpListView(list: list)
        }
        .cornerRadius(20)
        .padding()
    }
}
