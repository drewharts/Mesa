//
//  RestaurantDetailView.swift (PlaceDetailView)
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
    
    @State private var selectedImage: UIImage?

    @EnvironmentObject var userSession: UserSession
    @StateObject private var viewModel = PlaceDetailViewModel()

    var body: some View {
        ZStack {
            // 1) Main content (the sheet UI), blurred if an image is selected
            VStack(spacing: 16) {
                if sheetHeight == minSheetHeight {
                    MinPlaceDetailView(viewModel: viewModel,
                                       place: place,
                                       selectedImage: $selectedImage)
                } else {
                    // Or MaxPlaceDetailView if you prefer for expanded state
                    MinPlaceDetailView(viewModel: viewModel,
                                       place: place,
                                       selectedImage: $selectedImage)
                }
            }
            .onAppear {
                viewModel.loadData(for: place)
            }
            .alert(isPresented: $viewModel.showAlert) {
                Alert(title: Text("Success"),
                      message: Text(viewModel.alertMessage),
                      dismissButton: .default(Text("OK")))
            }
            .sheet(isPresented: $viewModel.showListSelection) {
                ListSelectionSheet(place: place, isPresented: $viewModel.showListSelection)
                    .environmentObject(userSession.profileViewModel!)
            }
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            // Apply blur when we have a selected image
            .blur(radius: selectedImage != nil ? 10 : 0)

            // 2) Overlay with the selected photo, centered
            if let selectedImage = selectedImage {
                // A fill container to detect taps outside the photo
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        self.selectedImage = nil
                    }
                    .ignoresSafeArea()

                // Centered enlarged photo
                VStack {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                        .onTapGesture {
                            // Tapping the photo also dismisses it
                            self.selectedImage = nil
                        }
                }
                // You can animate or transition if desired
                .transition(.opacity)
                .animation(.easeInOut, value: selectedImage)
            }
        }
    }
}
