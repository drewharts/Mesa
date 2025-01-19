//
//  UploadPhotosButtonView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct UploadPhotosButtonView: View {
    @Binding var showingImagePicker: Bool

    var body: some View {
        Button(action: {
            showingImagePicker = true
        }) {
            HStack(alignment: .center) {
                Image(systemName: "plus")
                    .foregroundColor(.black)
                    .padding(8)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
                Text("Upload photos")
                    .foregroundColor(.black)
                    .font(.footnote)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}