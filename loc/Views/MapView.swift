//
//  MapView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 7/13/24.
//

import SwiftUI
import MapboxMaps

struct MapView: View {
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var profile: ProfileViewModel
    
    private let defaultCenter = CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0)
    @State var viewport: Viewport = .camera(center: CLLocationCoordinate2D(latitude: 39.5, longitude: -98.0), zoom: 10)
    @State private var hasInitialized = false
    
    var onMapTap: (() -> Void)?
    
    var body: some View {
        let currentCoords = locationManager.currentLocation?.coordinate ?? defaultCenter

        Map(viewport: $viewport) {
            Puck2D()
            Puck2D(bearing: .heading)
            
            ForEvery(profile.userFavorites) { favorite in
                var tempPlaceLocation = CLLocationCoordinate2D(
                    latitude: favorite.coordinate!.latitude,
                    longitude: favorite.coordinate!.longitude
                )
                PointAnnotation(coordinate: tempPlaceLocation)
                    .image(.init(image: circularImage(from: profile.profilePhotoImage!), name: "profile"))
                    .onTapGesture {
                        selectedPlaceVM.selectedPlace = favorite
                        selectedPlaceVM.isDetailSheetPresented = true
                    }
            }
            
            ForEvery(profile.userLists) { list in
                if let places = profile.placeListGMSPlaces[list.id] {
                    ForEvery(places) { place in
                        PointAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: place.coordinate!.latitude,
                            longitude: place.coordinate!.longitude
                        ))
                        .image(.init(image: circularImage(from: profile.profilePhotoImage!), name: "profile"))
                        .onTapGesture {
                            selectedPlaceVM.selectedPlace = place
                            selectedPlaceVM.isDetailSheetPresented = true
                        }
                    }
                }
            }
            
            ForEvery(profile.friends) { friend in
                if let places = profile.friendPlaces[friend.id] {
                    ForEvery(places) { place in
                        PointAnnotation(coordinate: CLLocationCoordinate2D(
                            latitude: place.coordinate!.latitude, longitude: place.coordinate!.longitude
                        ))
                        .image(.init(image: UIImage(named: "DestPin") ?? UIImage(), name: "dest-pin"))
                        .onTapGesture {
                            selectedPlaceVM.selectedPlace = place
                            selectedPlaceVM.isDetailSheetPresented = true
                        }
                    }
                }
            }
            if let selectedPlace = selectedPlaceVM.selectedPlace {
                let currentPlaceLocation = CLLocationCoordinate2D(
                    latitude: selectedPlace.coordinate!.latitude,
                    longitude: selectedPlace.coordinate!.longitude
                )
//                PointAnnotation(coordinate: currentPlaceLocation)
//                    .image(.init(image: UIImage(named: "DestPin")!, name: "dest-pin"))
            }
        }
        .onTapGesture {
            self.onMapTap?()
        }
        .onAppear {
            if !hasInitialized {
                print("Initial setup with coords: \(currentCoords)")
                viewport = .camera(center: currentCoords, zoom: 13)
                hasInitialized = true
            }
        }
        .onChange(of: selectedPlaceVM.selectedPlace) { newPlace in
            guard let place = newPlace, let coordinate = place.coordinate else {
                print("No valid place or coordinate")
                return
            }
            let newCenter = CLLocationCoordinate2D(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            print("Updating camera to: \(newCenter)")
            withViewportAnimation(.easeOut(duration: 2.0)) {
                viewport = .camera(center: newCenter, zoom: 14)
            }
        }
    }
    
    private func circularImage(from image: UIImage?) -> UIImage {
            guard let image = image else {
                // Return a default image or placeholder if nil
                return UIImage(named: "defaultProfile") ?? UIImage()
            }
            
            let size = CGSize(width: 40, height: 40) // Adjust size as needed
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                let rect = CGRect(origin: .zero, size: size)
                
                // Create circular clipping path
                let circlePath = UIBezierPath(ovalIn: rect)
                circlePath.addClip()
                
                // Draw the image scaled to fit the circular bounds
                image.draw(in: rect)
                
                // Add thin white border
                context.cgContext.setStrokeColor(UIColor.white.cgColor)
                context.cgContext.setLineWidth(1.0) // Thin border, adjust as needed
                context.cgContext.strokeEllipse(in: rect.insetBy(dx: 0.5, dy: 0.5)) // Slightly inset to fit within bounds
            }
        }
}
