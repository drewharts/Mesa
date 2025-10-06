//
//  TravelTimeSelector.swift
//  loc
//
//  Created by Assistant on [current date]
//

import SwiftUI

struct TravelTimeSelector: View {
    @ObservedObject var viewModel: PlaceDetailViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager

    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0
    @State private var selectedTransportType: MapKitService.TransportType?

    private let buttonSize: CGFloat = 32
    private let expandedSize: CGFloat = 120
    private let animationDuration: Double = 0.2

    var body: some View {
        ZStack {
            backgroundOverlay
            mainContent
        }
        .animation(.easeInOut(duration: animationDuration), value: isExpanded)
    }

    private var backgroundOverlay: some View {
        Group {
            if isExpanded {
                Color.clear
                    .contentShape(Rectangle())
                    .allowsHitTesting(true)
            }
        }
    }

    private var mainContent: some View {
        transportSelector
    }

    private var transportSelector: some View {
        ZStack {
            // Main time display (only shown when not expanded)
            mainTimeDisplay

            // Expanded menu (only shown when expanded, appears above everything)
            if isExpanded {
                expandedMenu
                    .zIndex(1000) // Ensure it appears above all other content
            }
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if isExpanded {
                        handleDrag(value)
                    }
                }
                .onEnded { _ in
                    if isExpanded {
                        handleDragEnd()
                    }
                }
        )
    }

    private var availableTransportTypes: [MapKitService.TransportType] {
        // Always show all transport types, but they'll show "N/A" if not available
        MapKitService.TransportType.allCases
    }

    private var expandedMenu: some View {
        Group {
            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(availableTransportTypes, id: \.self) { transportType in
                        TransportTypeButton(
                            transportType: transportType,
                            isSelected: selectedTransportType == transportType,
                            currentTime: viewModel.travelTimes[transportType] ?? "N/A",
                            onTap: {
                                selectTransportType(transportType)
                                collapseMenu()
                            }
                        )
                    }
                }
                .padding(.vertical, 12)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(radius: 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var mainTimeDisplay: some View {
        Group {
            if !isExpanded {
                HStack(spacing: 4) {
                    Image(systemName: viewModel.currentTransportType.iconName)
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Text(viewModel.travelTime)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.3)
                        .onEnded { _ in
                            print("👆 [TravelTimeSelector] Long press detected - expanding menu")
                            expandMenu()
                        }
                )
                .onTapGesture {
                    print("👆 [TravelTimeSelector] Tap gesture triggered")
                    // Single tap opens navigation
                    if let place = selectedPlaceVM.selectedPlace,
                       let currentLocation = locationManager.currentLocation {
                        viewModel.openNavigation(for: place, currentLocation: currentLocation.coordinate)
                    } else {
                        print("❌ [TravelTimeSelector] Missing place or location data")
                    }
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func expandMenu() {
        isExpanded = true
    }

    private func collapseMenu() {
        isExpanded = false
        selectedTransportType = nil
        dragOffset = 0
    }

    private func handleDrag(_ value: DragGesture.Value) {
        let location = value.location

        // Simple calculation: each button is 44 points + 8 points spacing
        let itemHeight: CGFloat = 44
        let spacing: CGFloat = 8
        let totalItemHeight = itemHeight + spacing

        // Calculate which item the finger is over
        let itemIndex = Int(location.y / totalItemHeight)

        if itemIndex >= 0 && itemIndex < availableTransportTypes.count {
            selectedTransportType = availableTransportTypes[itemIndex]
        } else {
            selectedTransportType = nil
        }
    }

    private func handleDragEnd() {
        if let transportType = selectedTransportType {
            selectTransportType(transportType)
        }
        collapseMenu()
    }

    private func selectTransportType(_ transportType: MapKitService.TransportType) {
        print("🎯 [TravelTimeSelector] Switching to transport type: \(transportType.displayName)")
        viewModel.switchTransportType(to: transportType)
        // Save as default preference
        viewModel.saveDefaultTransportType(transportType)
        print("✅ [TravelTimeSelector] Current transport type is now: \(viewModel.currentTransportType.displayName)")
    }
}

// MARK: - Transport Type Button Component

struct TransportTypeButton: View {
    let transportType: MapKitService.TransportType
    let isSelected: Bool
    let currentTime: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: transportType.iconName)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: isSelected ? 36 : 44, height: isSelected ? 36 : 44)
                    .background(isSelected ? Color.blue : Color.clear)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(transportType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.black)

                    Text(displayTime)
                        .font(.caption)
                        .foregroundColor(timeColor)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .opacity(isAvailable ? 1.0 : 0.6)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isAvailable)
    }

    private var isAvailable: Bool {
        currentTime != "N/A" && currentTime != "Calculating..."
    }

    private var displayTime: String {
        if currentTime == "N/A" {
            return "Not available"
        }
        return currentTime
    }

    private var iconColor: Color {
        if isSelected {
            return .white
        }
        if !isAvailable {
            return .gray.opacity(0.5)
        }
        return .gray
    }

    private var timeColor: Color {
        if !isAvailable {
            return .gray.opacity(0.7)
        }
        return .gray
    }
}
