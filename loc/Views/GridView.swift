//
//  GridView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 12/5/24.
//


import SwiftUI

struct GridView: View {
    let images: [UIImage]
    
    // For a 3-column grid
    let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            // Loop only up to 9 items or images.count, whichever is smaller
            ForEach(0 ..< min(9, images.count), id: \.self) { index in
                ZStack {
                    GeometryReader { geo in
                        Image(uiImage: images[index])
                            .resizable()
                            .scaledToFill()
                            // Make the image square by using its width
                            .frame(width: geo.size.width, height: geo.size.width)
                            .clipped()
                            .cornerRadius(4)
                    }
                    .aspectRatio(1, contentMode: .fill)

                    // If it's the 9th image and there are more images left
                    if index == 8 && images.count > 9 {
                        // Dark semi-transparent overlay
                        Color.black.opacity(0.4)
                            .cornerRadius(4)
                        
                        // Display how many images remain
                        Text("+\(images.count - 9)")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
    }
}

