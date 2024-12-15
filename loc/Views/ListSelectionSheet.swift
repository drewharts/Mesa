//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import GooglePlaces

struct ListSelectionSheet: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var lists: PlaceListViewModel
    let place: GMSPlace
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var newListName = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add to Collection")
                .font(.headline)
                .padding()

            ScrollView {
                VStack(spacing: 15) {
                    // Button for creating a new collection
                    Button(action: {
                        showNewListSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create New Collection")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                    .sheet(isPresented: $showNewListSheet) {
                        NewListView(isPresented: $showNewListSheet, onSave: { listName in
                            profile.addNewPlaceList(named: listName, city: "", emoji: "", image: "")
                        })
                    }

                    // List of existing collections
                    ForEach(profile.placeListViewModels, id: \.placeList.id) { listViewModel in
                        Button(action: {
                            profile.getPlaceListViewModel(named: listViewModel.placeList.name)?.addPlace(place)
                            isPresented = false
                        }) {
                            HStack {
                                Text(listViewModel.placeList.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Cancel button
            Button("Cancel") {
                isPresented = false
            }
            .foregroundColor(.red)
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .padding()
    }

}
