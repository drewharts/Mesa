//
//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import GoogleMaps
import GooglePlaces

struct MapView: UIViewRepresentable {
    @ObservedObject var viewModel: MapViewModel
    @Binding var searchResults: [GMSAutocompletePrediction]

    var onMapTap: (() -> Void)? // Callback for map tap

    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView()
        mapView.isMyLocationEnabled = true
        mapView.delegate = context.coordinator
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if viewModel.shouldCenterOnUser {
                viewModel.recenterUser()
            }
        }
        
        return mapView
    }

    func updateUIView(_ uiView: GMSMapView, context: Context) {
        uiView.clear()
        
        viewModel.markers.forEach { $0.map = uiView }
        
        uiView.animate(to: viewModel.cameraPosition)

        // Clear search results if the flag is set
        if viewModel.shouldClearSearchResults {
            searchResults = []
            viewModel.resetClearSearchResults() // Reset the flag
            onMapTap?()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture {
                // Notify the ViewModel that the map has moved
                DispatchQueue.main.async {
                    self.parent.viewModel.onMapMoved()
                }
            }
        }
    }
}
