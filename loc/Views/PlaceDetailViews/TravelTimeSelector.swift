//
//  TravelTimeSelector.swift
//  loc
//
//  Travel time display with expandable transport type selector
//  Uses PreferenceKey pattern for proper overlay rendering at parent level
//

import SwiftUI

// MARK: - PreferenceKey for Position & State

/// Preference key to pass selector state and position up the view hierarchy
struct TravelTimeSelectorStateKey: PreferenceKey {
    static var defaultValue: TravelTimeSelectorState? = nil
    
    static func reduce(value: inout TravelTimeSelectorState?, nextValue: () -> TravelTimeSelectorState?) {
        value = nextValue() ?? value
    }
}

/// State passed up to parent for overlay rendering
struct TravelTimeSelectorState: Equatable {
    let frame: CGRect
    let isExpanded: Bool
    let selectedIndex: Int?
}

// MARK: - Travel Time Selector

struct TravelTimeSelector: View {
    @ObservedObject var viewModel: TravelTimeViewModel
    @EnvironmentObject var selectedPlaceVM: SelectedPlaceViewModel
    @EnvironmentObject var locationManager: LocationManager

    // Frame tracking for menu positioning (presentation concern only)
    @State private var buttonFrame: CGRect = .zero

    private let animationDuration: Double = 0.2

    var body: some View {
        mainTimeDisplay
            .background(
                GeometryReader { geo in
                    Color.clear
                        .preference(
                            key: TravelTimeSelectorStateKey.self,
                            value: TravelTimeSelectorState(
                                frame: geo.frame(in: .global),
                                isExpanded: viewModel.isMenuExpanded,
                                selectedIndex: viewModel.selectedMenuIndex
                            )
                        )
                        .onAppear {
                            buttonFrame = geo.frame(in: .global)
                        }
                        .onChange(of: geo.frame(in: .global)) { newFrame in
                            buttonFrame = newFrame
                        }
                }
            )
    }

    private var mainTimeDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: viewModel.currentTransportType.iconName)
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(viewModel.travelTime)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .opacity(viewModel.isMenuExpanded ? 0.3 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !viewModel.isMenuExpanded else { return }
            print("👆 [TravelTimeSelector] Tap gesture triggered")
            if let place = selectedPlaceVM.selectedPlace,
               let currentLocation = locationManager.currentLocation {
                viewModel.openNavigation(for: place, currentLocation: currentLocation.coordinate)
            } else {
                print("❌ [TravelTimeSelector] Missing place or location data")
            }
        }
        .gesture(
            LongPressGesture(minimumDuration: 0.3)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                .onChanged { value in
                    switch value {
                    case .first(true):
                        // Long press started - expand menu
                        withAnimation(.easeOut(duration: animationDuration)) {
                            viewModel.expandMenu()
                        }
                        print("👆 [TravelTimeSelector] Long press - expanding")
                    case .second(true, let drag?):
                        // Dragging after long press - update selection
                        updateDragSelection(drag)
                    default:
                        break
                    }
                }
                .onEnded { _ in
                    // Gesture ended - confirm selection if any, then collapse
                    withAnimation(.easeIn(duration: animationDuration)) {
                        _ = viewModel.confirmMenuSelection()
                    }
                }
        )
    }
    
    // MARK: - Drag Selection
    
    /// Updates the selected menu index based on drag position
    /// Provides haptic feedback when selection changes
    private func updateDragSelection(_ drag: DragGesture.Value) {
        // Calculate which item is being hovered based on drag location
        // Menu appears below button, each item is ~52pt tall
        let menuTop = buttonFrame.maxY + 10
        let itemHeight: CGFloat = 52
        let dragY = drag.location.y
        
        let newIndex: Int? = {
            guard dragY > menuTop else { return nil }
            
            let relativeY = dragY - menuTop
            let index = Int(relativeY / itemHeight)
            let transportTypes = MapKitService.TransportType.allCases
            
            return (index >= 0 && index < transportTypes.count) ? index : nil
        }()
        
        // Provide haptic feedback when selection changes
        if newIndex != viewModel.selectedMenuIndex {
            if newIndex != nil {
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
            }
            viewModel.updateSelectedIndex(newIndex)
        }
    }
}

// MARK: - Expanded Menu View (Rendered by Parent)

struct TravelTimeSelectorExpandedMenu: View {
    let viewModel: TravelTimeViewModel
    let selectedIndex: Int?
    let onSelect: (MapKitService.TransportType) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(MapKitService.TransportType.allCases.enumerated()), id: \.element) { index, transportType in
                TransportTypeButton(
                    transportType: transportType,
                    isSelected: selectedIndex == index,
                    currentTime: viewModel.travelTimes[transportType] ?? "N/A",
                    onTap: {
                        onSelect(transportType)
                    }
                )
            }
        }
        .padding(.vertical, 12)
        .frame(width: 200)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(radius: 8)
    }
}

// MARK: - Transport Type Button

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
                    .foregroundColor(isSelected ? .white : iconColor)
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
        currentTime == "N/A" ? "Not available" : currentTime
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
