//
//  SaveListButton.swift
//  loc
//
//  DUMB Component: Bookmark button to save/unsave a list.
//  Single Responsibility: Toggle saved state for a given list ID.
//

import SwiftUI

/// Bookmark button that saves or unsaves a list via SavedListsViewModel.
struct SaveListButton: View {
    let listId: String
    @ObservedObject var savedListsViewModel: SavedListsViewModel

    var body: some View {
        Button(action: {
            Task {
                if savedListsViewModel.isListSaved(listId: listId) {
                    _ = await savedListsViewModel.unsaveList(listId: listId)
                } else {
                    _ = await savedListsViewModel.saveList(listId: listId)
                }
            }
        }) {
            Image(systemName: savedListsViewModel.isListSaved(listId: listId) ? "bookmark.fill" : "bookmark")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(.primary)
        }
        .frame(width: 44, height: 44)
    }
}
