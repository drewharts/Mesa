//
//  PostReviewButtonView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct SharePostButtonView: View {
    @Binding var highlighted: Bool
    @Binding var isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
        }) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .padding(.horizontal, 40)
                    .background(highlighted ? Color.green : Color.gray.opacity(0.2))
                    .cornerRadius(20)
            } else {
                Text("SHARE POST")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .padding(.horizontal, 40)
                    .background(highlighted ? Color.green : Color.gray.opacity(0.2))
                    .foregroundColor(highlighted ? .white : .black)
                    .cornerRadius(20)
            }
        }
        .disabled(isLoading)
    }
}
