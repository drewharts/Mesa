//
//  RestaurantDetailView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces

struct PlaceDetailView: View {
    let place: GMSPlace
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat

    @EnvironmentObject var profile: ProfileViewModel

    @StateObject private var viewModel = PlaceDetailViewModel()

    var body: some View {
        VStack(spacing: 16) {
            // minimum sheet
            if sheetHeight == minSheetHeight {
                MinPlaceDetailView(viewModel: viewModel, place: place)
            } else {
                // Expanded State Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        headerView
                        if !viewModel.photos.isEmpty {
                            GridView(images: viewModel.photos)
                        } else {
                            ProgressView("Loading Photos...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        addressAndHoursView
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear { viewModel.loadData(for: place) }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(title: Text("Success"), message: Text(viewModel.alertMessage), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $viewModel.showListSelection) {
            ListSelectionSheet(place: place, isPresented: $viewModel.showListSelection)
                .environmentObject(profile)
        }
        .padding(.vertical)
        .frame(maxWidth: .infinity)
    }

    private var headerView: some View {
        HStack(alignment: .top, spacing: 8) {
            if let iconURL = viewModel.placeIconURL {
                AsyncImage(url: iconURL) { phase in
                    if let image = phase.image {
                        image.resizable()
                            .scaledToFit()
                            .frame(width: 75, height: 75)
                            .cornerRadius(8)
                            .padding(10)
                    } else if phase.error != nil {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(width: 40, height: 40)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.placeName)
                    .font(.title)
                    .foregroundStyle(.gray)
                    .bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: { viewModel.showDirections() }) {
                    Text("Directions")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                        .padding(8)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray, lineWidth: 2))
                }
            }

            Button(action: { viewModel.handleAddButton() }) {
                Image(systemName: "plus")
                    .padding(8)
                    .background(Circle().fill(Color.gray.opacity(0.2)))
                    .foregroundStyle(.black)
            }
            .frame(width: 40)
        }
        .padding(.horizontal)
    }

    private var addressAndHoursView: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let openingHours = viewModel.openingHours {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Opening Hours:")
                        .font(.headline)
                        .foregroundColor(.black)
                    ForEach(openingHours, id: \.self) { hour in
                        Text(hour)
                            .font(.subheadline)
                            .foregroundColor(.black)
                    }
                }
            } else {
                Text("Opening hours not available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
    }
}
