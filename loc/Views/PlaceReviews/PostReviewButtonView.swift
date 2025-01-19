//
//  PostReviewButtonView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct PostReviewButtonView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("POST REVIEW")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.black)
                .cornerRadius(20)
        }
        .padding(.horizontal, 40)
    }
}