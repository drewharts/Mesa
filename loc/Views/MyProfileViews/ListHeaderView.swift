//
//  ListHeaderView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ListHeaderView: View {
    var onAddList: () -> Void
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("LISTS")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.black)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchActive.toggle()
                            if !isSearchActive {
                                searchText = ""
                            }
                        }
                    }) {
                        Image(systemName: isSearchActive ? "xmark" : "magnifyingglass")
                            .foregroundColor(.gray)
                    }
                    
                    Button(action: onAddList) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, -15)
    }
}
