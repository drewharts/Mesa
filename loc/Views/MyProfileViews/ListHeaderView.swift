//
//  ListHeaderView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI
import UIKit

struct ListHeaderView: View {
    var onAddList: () -> Void
    @Binding var searchText: String
    @State private var isSearchExpanded = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("LISTS")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.black)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isSearchExpanded.toggle()
                            if !isSearchExpanded {
                                searchText = ""
                            }
                        }
                    }) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                    
                    Button(action: onAddList) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.gray)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 20)
            
            // Expandable search bar
            if isSearchExpanded {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                    
                    TextField("Search your lists...", text: $searchText)
                        .font(.subheadline)
                        .foregroundColor(.black)
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 14))
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}
