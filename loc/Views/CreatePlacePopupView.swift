//  CreatePlacePopupView.swift
//  loc

import SwiftUI
import CoreLocation

struct CreatePlacePopupView: View {
    @StateObject private var viewModel: CreatePlaceSheetViewModel
    @Environment(\.dismiss) private var dismiss

    let onCreatePlace: (String, String?) -> Void

    /// Initializes the sheet with a coordinate and creation callback.
    init(coordinate: CLLocationCoordinate2D, onCreatePlace: @escaping (String, String?) -> Void) {
        self._viewModel = StateObject(wrappedValue: CreatePlaceSheetViewModel(coordinate: coordinate))
        self.onCreatePlace = onCreatePlace
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    CreatePlaceNameField(placeName: $viewModel.placeName)
                    CreatePlaceDescriptionField(placeDescription: $viewModel.placeDescription)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .navigationTitle("New Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Button("Create") {
                            onCreatePlace(
                                viewModel.placeName.trimmingCharacters(in: .whitespacesAndNewlines),
                                viewModel.trimmedDescription
                            )
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .disabled(!viewModel.canCreate)
                    }
                }
            }
            .onTapGesture {
                UIApplication.shared.endEditing()
            }
        }
    }
}

#Preview {
    CreatePlacePopupView(
        coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    ) { name, description in
        print("Created place: \(name)")
        if let description = description {
            print("Description: \(description)")
        }
    }
}
