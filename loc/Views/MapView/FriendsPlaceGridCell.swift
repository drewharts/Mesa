//
//  FriendsPlaceGridCell.swift
//  loc
//
//  Dumb Component: Displays a friends/network place in the grid.
//  
//  Single Responsibility: Render place data as a grid cell
//  - Receives all data via parameters (no EnvironmentObject for business data)
//  - Communicates actions via callbacks
//  - No business logic, no navigation, no network calls
//

import SwiftUI

struct FriendsPlaceGridCell: View {
    
    // MARK: - Input (Data)
    
    let item: VisiblePlaceItem
    let image: UIImage?
    
    // MARK: - Output (Callbacks)
    
    let onTap: () -> Void
    
    // MARK: - Computed Properties
    
    private var placeColor: Color {
        let hash = item.id.hashValue
        let hue = Double(abs(hash) % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.8)
    }
    
    // MARK: - Body
    
    var body: some View {
        Rectangle()
            .fill(placeColor)
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                GeometryReader { geometry in
                    ZStack(alignment: .bottom) {
                        photoContent(size: geometry.size)
                        gradientOverlay
                        placeInfoOverlay
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
            .onTapGesture(perform: onTap)
    }
    
    // MARK: - Subviews
    
    private var gradientOverlay: some View {
        LinearGradient(
            gradient: Gradient(colors: [.clear, .black.opacity(0.7)]),
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
    
    private var placeInfoOverlay: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.name)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(1)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Photo Content
    
    @ViewBuilder
    private func photoContent(size: CGSize) -> some View {
        if let uiImage = image {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            // Placeholder - just shows the background color
            Color.clear
        }
    }
}
