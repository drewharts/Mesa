//
//  ListSelectionSheet.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/25/24.
//

import SwiftUI
import GooglePlaces

struct ListSelectionSheet: View {
    @EnvironmentObject var profile: Profile
    let place: GMSPlace
    @Binding var isPresented: Bool
    @State private var showNewListSheet = false
    @State private var newListName = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Add to collection")
                .font(.headline)
                .padding()

            ScrollView {
                VStack(spacing: 15) {
                    Button(action: {
                        showNewListSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Create collection")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                    .sheet(isPresented: $showNewListSheet) {
                        NewListView(isPresented: $showNewListSheet, onSave: { listName in
                            createNewList(named: listName)
                        })
                    }

                    ForEach(profile.placeLists) { list in
                        Button(action: {
                            addToExistingList(list)
                            isPresented = false
                        }) {
                            HStack {
                                Text(list.name)
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

    private func createNewList(named listName: String) {
        let trimmedName = listName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        let newList = PlaceList(name: trimmedName)
        profile.addPlacesList(newList)
        profile.addPlace(place: place, to: newList)
    }

    private func addToExistingList(_ list: PlaceList) {
        profile.addPlace(place: place, to: list)
    }
}
