//
//  UserProfileFavoritesView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/29/25.
//

import SwiftUI
import MapboxSearch

struct UserProfileFavoritesView: View {
    var userFavorites: [DetailPlace]
    var placeImages: [String: UIImage]
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @Environment(\.presentationMode) var presentationMode
    @State private var placeColors: [UUID: Color] = [:]
    @State private var emptyCircleColors: [Int: Color] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FAVORITES")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20) // Keep this consistent
                .foregroundStyle(.black)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    ForEach(0..<4) { index in
                        if index < userFavorites.count {
                            VStack(spacing: 4) {
                                if let image = placeImages[userFavorites[index].id.uuidString] {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 85, height: 85)
                                        .cornerRadius(50)
                                        .clipped()
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 85, height: 85)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                } else {
                                    Circle()
                                        .frame(width: 85, height: 85)
                                        .foregroundColor(placeColors[userFavorites[index].id] ?? .green)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 85, height: 85)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                }

                                Text(userFavorites[index].name.prefix(15) ?? "Unknown")
                                    .foregroundColor(.black)
                                    .fontWeight(.semibold)
                                    .font(.footnote)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 85)
                                Text(userFavorites[index].city?.prefix(15) ?? "")
                                    .foregroundColor(.black)
                                    .font(.caption)
                                    .fontWeight(.light)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(1)
                                    .frame(width: 85)
                            }
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                selectedPlaceVM.selectedPlace = userFavorites[index]
                                selectedPlaceVM.isDetailSheetPresented = true
                                presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            VStack(spacing: 4) {
                                Circle()
                                    .frame(width: 85, height: 85)
                                    .foregroundColor(emptyCircleColors[index] ?? randomColor())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 85, height: 85)
                                    )
                                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                                
                                if !userFavorites.isEmpty {
                                    Text("")
                                        .foregroundColor(.black)
                                        .fontWeight(.semibold)
                                        .font(.footnote)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .frame(width: 85)
                                    Text("")
                                        .foregroundColor(.black)
                                        .font(.caption)
                                        .fontWeight(.light)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(1)
                                        .frame(width: 85)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: userFavorites.isEmpty ? 85 : 120)
        }
        .onAppear {
            for place in userFavorites {
                if placeColors[place.id] == nil {
                    placeColors[place.id] = randomColor()
                }
            }
            
            // Set random colors for empty circles
            for index in 0..<4 {
                if index >= userFavorites.count {
                    emptyCircleColors[index] = randomColor()
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
}
