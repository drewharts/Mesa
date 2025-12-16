//
//  PlacePostHeaderView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI

struct PlacePostHeaderView: View {
    let placeName: String

    var body: some View {
        VStack(spacing: 16) {
            Text(placeName)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Text("Share your experience")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Divider()
                .padding(.top, 15)
                .padding(.bottom, 15)
                .padding(.horizontal, -10)
        }
    }
}
