//
//  ProfileViewListsView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/14/24.
//

import SwiftUI
import PhotosUI

struct ProfileViewListsView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var detailPlaceViewModel: DetailPlaceViewModel
    @Environment(\.presentationMode) private var presentationMode

    @State private var showingImagePicker = false
    @State private var inputImage: [UIImage] = []
    @State private var selectedList: PlaceListViewModel?
    @State private var showingNewListSheet = false
    @State private var searchText = ""
    @State private var isSearchActive = false
    @State private var placeColors: [UUID: Color] = [:]
    @FocusState private var isTextFieldFocused: Bool
    
    // Filtered and sorted lists based on search
    var filteredLists: [PlaceList] {
        let sorted = profile.userLists.sorted { $0.sortOrder < $1.sortOrder }
        if searchText.isEmpty {
            return sorted
        } else {
            return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 16) {
                ListHeaderView(
                    onAddList: {
                        showingNewListSheet = true
                    },
                    searchText: $searchText,
                    isSearchActive: $isSearchActive
                )

                if !filteredLists.isEmpty {
                    ForEach(filteredLists, id: \ .id) { list in
                        ProfileListSection(
                            list: list,
                            placeIds: profile.userListsPlaces[list.id.uuidString],
                            detailPlaceViewModel: detailPlaceViewModel,
                            placeColors: $placeColors
                        )
                    }
                } else {
                    VStack(spacing: 8) {
                        if searchText.isEmpty {
                            Text("No lists available")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        } else {
                            Text("No lists found")
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            Text("No lists match '\(searchText)'")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
            
            // Floating search bar above keyboard
            if isSearchActive {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                        
                        TextField("Search your lists...", text: $searchText)
                            .font(.body)
                            .foregroundColor(.black)
                            .focused($isTextFieldFocused)
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 16))
                            }
                        }
                        
                        Button("Done") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isSearchActive = false
                                isTextFieldFocused = false
                                searchText = ""
                            }
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .ignoresSafeArea(.keyboard, edges: .bottom)
                }
                .transition(.move(edge: .bottom))
            }
        }
        .onChange(of: isSearchActive) { active in
            if active {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTextFieldFocused = true
                }
            } else {
                isTextFieldFocused = false
            }
        }
        .onChange(of: isTextFieldFocused) { focused in
            if !focused && isSearchActive {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isSearchActive = false
                    searchText = ""
                }
            }
        }
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
