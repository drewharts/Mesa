//
//  PostReviewButtonView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct PostReviewButtonView: View {
    @Binding var highlighted: Bool
    @State private var isLoading = false  // Add loading state
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            isLoading = true  // Set loading true when tapped
            action()
        }) {
            if isLoading {
                ProgressView()  // Show loading indicator
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(highlighted ? Color.green : Color.gray.opacity(0.2))
                    .cornerRadius(20)
            } else {
                Text("POST REVIEW")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(highlighted ? Color.green : Color.gray.opacity(0.2))
                    .foregroundColor(highlighted ? .white : .black)
                    .cornerRadius(20)
            }
        }
        .padding(.horizontal, 40)
        .disabled(isLoading)  // Disable button while loading
    }
}
