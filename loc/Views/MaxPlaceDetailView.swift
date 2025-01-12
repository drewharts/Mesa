//
//  MaxPlaceDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/10/25.
//

import SwiftUI
import UIKit
import GooglePlaces

struct MaxPlaceDetailView: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    let place: GMSPlace

    var body: some View {
        HStack(alignment: .center, spacing: 15) {
            
            // CALL Bubble (Button)
            Button(action: {
                if let phoneNumber = place.phoneNumber,
                   let url = URL(string: "tel://\(phoneNumber)") {
                    UIApplication.shared.open(url)
                }
            }) {
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
                .clipShape(Capsule())
            }

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
        
        Text("PHOTOS")
            .font(.subheadline)
            .foregroundColor(.black)
            .fontWeight(.semibold)
            .padding(.bottom, 15)
        
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !viewModel.photos.isEmpty {
                    GridView(images: viewModel.photos)
                } else {
                    ProgressView("Loading Photos...")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
    }
}
