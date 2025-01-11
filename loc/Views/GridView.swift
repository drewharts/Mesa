//
//  GridView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//


import SwiftUI

struct GridView: View {
    let images: [UIImage]
    
    // Three flexible columns
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(images.indices, id: \.self) { index in
                // Instead of specifying .frame(width: 115, height: 115), do:
                Image(uiImage: images[index])
                    .resizable()
                    .scaledToFill()
                    .aspectRatio(1, contentMode: .fill) // keep them square
                    .clipped()
                    .cornerRadius(4)
            }
        }
        // Overall grid padding
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
}
