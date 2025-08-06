//
//  SelectedImagesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//

import SwiftUI

struct SelectedImagesView: View {
    @Binding var images: [UIImage]

    var body: some View {
        content
    }
    
    @ViewBuilder
    private var content: some View {
        if images.isEmpty {
            emptyView
        } else {
            imagesScrollView
        }
    }
    
    private var emptyView: some View {
        Text("No images")
            .foregroundColor(.gray)
    }
    
    private var imagesScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<images.count, id: \.self) { index in
                    imageCell(at: index)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10) // Add top padding to accommodate the X button
        }
    }
    
    private func imageCell(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            
            removeButton(for: index)
        }
    }
    
    private func removeButton(for index: Int) -> some View {
        Button(action: {
            removeImage(at: index)
        }) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.gray)
                .background(Color.white)
                .clipShape(Circle())
                .font(.system(size: 18))
        }
        .offset(x: 10, y: -10) // Increased offset to ensure full visibility
    }
    
    private func removeImage(at index: Int) {
        _ = withAnimation(.easeInOut(duration: 0.2)) {
            images.remove(at: index)
        }
    }
}

