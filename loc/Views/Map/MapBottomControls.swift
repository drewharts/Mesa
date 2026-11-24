//
//  MapBottomControls.swift
//  loc
//
//  DUMB Component: map layer options and the current-location button, stacked bottom-right
//  just above the tab bar (Google Maps layout).
//

import SwiftUI

/// Layers menu (who to show, satellite) above the "show my location" button.
struct MapBottomControls: View {
    @Binding var annotationDisplayMode: AnnotationDisplayMode
    @Binding var isSatelliteMap: Bool
    let onRecenterTap: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            layersMenu
            MapCircleButton(
                systemName: "location.fill",
                tint: .mesaAccent,
                accessibilityLabel: "Show my location",
                action: onRecenterTap
            )
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Subviews

    private var layersMenu: some View {
        Menu {
            Picker("Display", selection: $annotationDisplayMode) {
                ForEach(AnnotationDisplayMode.allCases, id: \.self) { mode in
                    Label(mode.label, systemImage: mode.iconName).tag(mode)
                }
            }
            Toggle(isOn: $isSatelliteMap) {
                Label("Satellite", systemImage: "globe.americas")
            }
        } label: {
            MapCircleButtonLabel(systemName: "square.3.layers.3d")
        }
        .accessibilityLabel("Map layers")
    }
}
