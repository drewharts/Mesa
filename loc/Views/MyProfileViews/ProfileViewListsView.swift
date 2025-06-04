//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI
import MapboxSearch

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var placeColors: [UUID: Color] = [:]
    
    // Precompute sorted lists
    var sortedLists: [PlaceList] {
        profile.userLists.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ListHeaderView(onAddList: {
                showingNewListSheet = true
            })

            if !sortedLists.isEmpty {
                ForEach(sortedLists, id: \ .id) { list in
                    ProfileListSection(
                        list: list,
                        placeIds: profile.userListsPlaces[list.id.uuidString],
                        detailPlaceViewModel: detailPlaceViewModel,
                        placeColors: $placeColors
                    )
                }
            } else {
                Text("No lists available")
                    .foregroundColor(.gray)
                    .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(images: $inputImage, selectionLimit: 1)
        }
        .sheet(isPresented: $showingNewListSheet) {
            NewListView(isPresented: $showingNewListSheet, onSave: { listName in
                profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
            })
        }
        .onChange(of: selectedPlaceVM.isDetailSheetPresented) { newValue in
            if newValue == true {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
