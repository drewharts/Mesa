//
//  SearchBar.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/5/24.
//


import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        TextField("Search here...", text: $text)
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .foregroundStyle(Color.gray)
    }
}
