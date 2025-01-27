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

    // Environment objects.
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    
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
                    MinPlaceDetailView(viewModel: viewModel, selectedImage: $selectedImage)
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
                // Load the place on first appear if one exists.
                if let place = selectedPlaceVM.selectedPlace {
                    viewModel.loadData(for: place)
                }
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
                // Whenever the selected place changes, load new data
                if let place = newPlace {
                    viewModel.loadData(for: place)
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
