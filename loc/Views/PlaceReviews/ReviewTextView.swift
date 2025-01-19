//
//  ReviewTextView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct ReviewTextView: View {
    @Binding var reviewText: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $reviewText)
                .font(.subheadline)
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .background(.gray.opacity(0.3))
                .cornerRadius(8)
                .foregroundStyle(.black)

            if reviewText.isEmpty {
                Text("Add a review...")
                    .font(.subheadline)
                    .foregroundColor(.black)
                    .font(.footnote)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .allowsHitTesting(false)
            }
        }
    }
}