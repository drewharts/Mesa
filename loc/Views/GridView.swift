//
//  GridView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//


import SwiftUI

struct GridView: View {
    let images: [UIImage]

    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(images.indices, id: \.self) { index in
                Image(uiImage: images[index]) // Wrap UIImage in a SwiftUI Image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 125, height: 100)
                    .clipped()
                    .cornerRadius(8)
            }
        }
    }
}
