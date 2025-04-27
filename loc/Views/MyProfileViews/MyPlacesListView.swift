import SwiftUI
import UIKit
import FirebaseFirestore

struct MyPlacesListView: View {
    @EnvironmentObject var profile: ProfileViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var placeColors: [UUID: Color] = [:]
    
    private let columns = [
        GridItem(.flexible(), spacing: 15),
        GridItem(.flexible(), spacing: 15)
    ]
    
    private let cardWidth: CGFloat = UIScreen.main.bounds.width / 2 - 35
    private let cardHeight: CGFloat = 180
    
    var createdPlaces: [DetailPlace] {
        profile.myCreatedPlaceIds.compactMap { id in
            profile.detailPlaceViewModel.places[id]
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if createdPlaces.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Text("No Places Created Yet")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray)
                        
                        Text("When you create a place, it'll appear here.")
                            .font(.body)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 15) {
                            ForEach(createdPlaces) { place in
                                Button(action: {
                                    selectedPlaceVM.selectedPlace = place
                                    selectedPlaceVM.isDetailSheetPresented = true
                                    presentationMode.wrappedValue.dismiss()
                                }) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ZStack(alignment: .bottom) {
                                            if let image = profile.detailPlaceViewModel.placeImages[place.id.uuidString] {
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: cardWidth, height: cardHeight)
                                                    .clipped()
                                            } else {
                                                Rectangle()
                                                    .foregroundColor(colorForPlace(place))
                                                    .frame(width: cardWidth, height: cardHeight)
                                            }
                                            
                                            // Gradient overlay
                                            LinearGradient(
                                                gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
                                                startPoint: .top,
                                                endPoint: .bottom
                                            )
                                            .frame(height: 60)
                                            
                                            // Place name and address
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(place.name)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                if let address = place.address {
                                                    Text(address)
                                                        .font(.caption)
                                                        .foregroundColor(.white.opacity(0.8))
                                                        .lineLimit(1)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.bottom, 8)
                                        }
                                    }
                                    .frame(width: cardWidth, height: cardHeight)
                                    .background(Color.white)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white, lineWidth: 2)
                                    )
                                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                    }
                }
            }
            .navigationTitle("My Places")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            for place in createdPlaces {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = randomColor()
                }
            }
        }
    }
    
    private func randomColor() -> Color {
        Color(
            red: Double.random(in: 0...1),
            green: Double.random(in: 0...1),
            blue: Double.random(in: 0...1)
        )
    }
    
    private func colorForPlace(_ place: DetailPlace) -> Color {
        placeColors[place.id] ?? .gray
    }
} 
