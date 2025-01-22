//
//  PostReviewButtonView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct PostReviewButtonView: View {
    @Binding var highlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("POST REVIEW")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                // Change button background color if highlighted
                .background(highlighted ? Color.green : Color.gray.opacity(0.2))
                .foregroundColor(highlighted ? .white : .black)
                .cornerRadius(20)
        }
        .padding(.horizontal, 40)
    }
}
