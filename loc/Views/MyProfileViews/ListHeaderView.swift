//
//  ListHeaderView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 5/29/25.
//
import SwiftUI

struct ListHeaderView: View {
    var onAddList: () -> Void
    
    var body: some View {
        HStack {
            Text("LISTS")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black)
            
            Button(action: onAddList) {
                Image(systemName: "plus.circle")
                    .foregroundColor(.gray)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.vertical, -25)
        .padding(.horizontal, 10)
    }
}
