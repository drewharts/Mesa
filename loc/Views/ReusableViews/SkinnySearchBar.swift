//
//  SearchBar.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/16/25.
//


import SwiftUI

struct SkinnySearchBar: View {
    @State private var searchText: String = ""

    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .padding(.leading, 8)

            TextField("Find a list", text: $searchText)
                .foregroundColor(.black)
                .foregroundStyle(.black)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
        }
        .background(.white)
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 15)
    }
}
