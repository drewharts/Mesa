//
//  RestaurantDetailView.swift (PlaceDetailView)
//  loc
//
//  Created by Andrew Hartsfield II on 11/8/24.
//

import SwiftUI
import GooglePlaces

struct PlaceDetailView: View {
    @Binding var sheetHeight: CGFloat
    let minSheetHeight: CGFloat

    @State private var selectedImage: UIImage?
    @State private var showNoPhoneNumberAlert = false


    // Environment objects.
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager

    // ViewModel owned by SwiftUI
    @StateObject private var viewModel = PlaceDetailViewModel()

    init(sheetHeight: Binding<CGFloat>, minSheetHeight: CGFloat) {
        self._sheetHeight = sheetHeight
        self.minSheetHeight = minSheetHeight
    }

    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                if viewModel.placeName == "Unknown" && viewModel.photos.isEmpty {
                    ProgressView("Loading Place Details...")
                } else {
                    MinPlaceDetailView(viewModel: viewModel, showNoPhoneNumberAlert: $showNoPhoneNumberAlert, selectedImage: $selectedImage)
                }
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .blur(radius: selectedImage != nil ? 10 : 0)
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Success"),
                      message: Text(viewModel.alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .alert(isPresented: $showNoPhoneNumberAlert) {
                Alert(
                    title: Text("Phone Number Not Available"),
                    message: Text("No phone number is available for this place."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(isPresented: $viewModel.showListSelection) {
                if let selectedPlace = selectedPlaceVM.selectedPlace {
                    ListSelectionSheet(
                        place: selectedPlace,
                        isPresented: $viewModel.showListSelection
                    )
                    .environmentObject(profile)
                } else {
                    Text("No place selected")
                }
            }
            .onAppear {
                if let place = selectedPlaceVM.selectedPlace,
                   let currentLocation = locationManager.currentLocation {
                    viewModel.loadData(for: place, currentLocation: currentLocation.coordinate)
                }
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
                if let place = newPlace,
                   let currentLocation = locationManager.currentLocation {
                    viewModel.loadData(for: place, currentLocation: currentLocation.coordinate)
                }
            }

            // Overlay for the enlarged photo
            if let selectedImage {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.selectedImage = nil
                    }
                    .ignoresSafeArea()

                VStack {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.gray, lineWidth: 1)
                        )
                        .padding()
                        .onTapGesture {
                            self.selectedImage = nil
                        }
                }
                .transition(.opacity)
                .animation(.easeInOut, value: selectedImage)
            }
        }
    }
}
