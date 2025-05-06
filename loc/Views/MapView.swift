//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapKit

struct MapView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var detailPlaceVM: DetailPlaceViewModel
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var showCreatePlacePopup = false
    @State private var newPlaceName = ""
    @State private var newPlaceDescription = ""
    @State private var newPlaceCoordinate: CLLocationCoordinate2D?
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter
        let places = detailPlaceVM.getAllSavedDetailPlaces().compactMap { place -> PlaceAnnotationItem? in
            guard let geoPoint = place.coordinate else { return nil }
            return PlaceAnnotationItem(
                id: place.id,
                coordinate: CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude),
                place: place
            )
        }
        
        ZStack {
            Map(coordinateRegion: $region, annotationItems: places) { item in
                MapAnnotation(coordinate: item.coordinate) {
                    if let annotationImage = detailPlaceVM.placeAnnotations[item.place.id.uuidString] {
                        Image(uiImage: annotationImage)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                            .onTapGesture {
                                selectedPlaceVM.selectedPlace = item.place
                                selectedPlaceVM.isDetailSheetPresented = true
                            }
                    } else {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 30, height: 30)
                            .onTapGesture {
                                selectedPlaceVM.selectedPlace = item.place
                                selectedPlaceVM.isDetailSheetPresented = true
                            }
                    }
                }
            }
            .onAppear {
                region.center = currentCoords
                region.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            }
            .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
                guard let place = newPlace, let geoPoint = place.coordinate else { return }
                let newCenter = CLLocationCoordinate2D(latitude: geoPoint.latitude, longitude: geoPoint.longitude)
                withAnimation {
                    region.center = newCenter
                    region.span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                }
            }
            // Optionally, add long press gesture for creating a new place
            // .gesture(LongPressGesture().onEnded { value in ... })
            // Add popup for creating a new place if needed
        }
    }
}

struct PlaceAnnotationItem: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let place: DetailPlace
}
