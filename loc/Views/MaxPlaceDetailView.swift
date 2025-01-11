//
//  MaxPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI

struct MaxPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            
            // CALL Bubble
            HStack(spacing: 8) {
                Image(systemName: "phone")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Text("CALL")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule()) // Gives that rounded “pill” shape

            // HOURS Bubble
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Text("HOURS")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())

            // MENU Bubble
            HStack(spacing: 8) {
                Image(systemName: "fork.knife.circle")
                    .font(.subheadline)
                    .foregroundColor(.black)
                Text("MENU")
                    .font(.subheadline)
                    .foregroundColor(.black)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .center)
        
        Divider()
            .padding(.top, 15)
            .padding(.bottom, 15)
        
        //photos
        Text("PHOTOS")
            .font(.subheadline)
            .foregroundColor(.black)
            .fontWeight(.semibold)
            .padding(.bottom, 15)
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // The actual grid
                if !viewModel.photos.isEmpty {
                    GridView(images: viewModel.photos)
                } else {
                    ProgressView("Loading Photos...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            // Optional: adjust if you want more/less vertical spacing
            .padding(.bottom, 20)
        }

    }
}
