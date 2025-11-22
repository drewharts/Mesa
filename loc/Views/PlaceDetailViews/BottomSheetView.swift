//
//  BottomSheetView.swift
//  loc
//
//  Created by Andrew Hartsfield II on 11/9/24.
//

import SwiftUI
import UIKit

struct BottomSheetView<Content: View>: View {
    @Binding var sheetHeight: CGFloat
    @Binding var isPresented: Bool
    let minSheetHeight: CGFloat
    let maxSheetHeight: CGFloat
    @GestureState private var dragTranslation: CGFloat = 0
    @Environment(\.allowChildDrag) private var allowChildDrag
    let content: Content

    init(
        isPresented: Binding<Bool>,
        sheetHeight: Binding<CGFloat>,
        minSheetHeight: CGFloat = 200,
        maxSheetHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self._sheetHeight = sheetHeight
        self.minSheetHeight = minSheetHeight
        self.maxSheetHeight = maxSheetHeight
        self.content = content()
    }

    // Computed property to determine if scrolling should be enabled
    private var isScrollingEnabled: Bool {
        sheetHeight == maxSheetHeight
    }

    // MARK: - Drag Handling Methods
    
    /// Handle ongoing drag gesture changes
    private func handleDragChange(_ translation: CGFloat) {
        let newHeight = sheetHeight - translation
        
        if newHeight <= maxSheetHeight && newHeight >= minSheetHeight {
            sheetHeight = newHeight
        } else if newHeight > maxSheetHeight {
            sheetHeight = maxSheetHeight
        } else if newHeight < minSheetHeight {
            sheetHeight = minSheetHeight
        }
    }
    
    /// Handle drag gesture end - snap to position or dismiss
    private func handleDragEnd(translation: CGFloat) {
        let newHeight = sheetHeight - translation
        let dismissalThreshold: CGFloat = 100
        let midpoint = (maxSheetHeight + minSheetHeight) / 2
        
        withAnimation {
            if translation > dismissalThreshold {
                // Reset height to max before dismissing so next open starts at max
                sheetHeight = maxSheetHeight
                isPresented = false
            } else if newHeight > midpoint {
                sheetHeight = maxSheetHeight
            } else {
                sheetHeight = minSheetHeight
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 0) {
                    Capsule()
                        .fill(Color.gray.opacity(0.5))
                        .frame(width: 40, height: 6)
                        .padding(.top, 8)
                    
                    // Pass isScrollingEnabled to content
                    content.environment(\.isScrollingEnabled, isScrollingEnabled)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                .frame(height: sheetHeight)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .cornerRadius(16, corners: [.topLeft, .topRight])
                .clipped()
                .gesture(
                    allowChildDrag ? nil :
                    DragGesture()
                        .updating($dragTranslation) { value, state, _ in
                            state = value.translation.height
                        }
                        .onEnded { value in
                            handleDragEnd(translation: value.translation.height)
                        }
                )
                .onChange(of: dragTranslation) {
                    handleDragChange(dragTranslation)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.all)
    }
}

// Custom Environment Key for passing scroll state
private struct IsScrollingEnabledKey: EnvironmentKey {
    static let defaultValue: Bool = true
}

extension EnvironmentValues {
    var isScrollingEnabled: Bool {
        get { self[IsScrollingEnabledKey.self] }
        set { self[IsScrollingEnabledKey.self] = newValue }
    }
}

// Custom Environment Key for allowing child drag gestures
private struct AllowChildDragKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var allowChildDrag: Bool {
        get { self[AllowChildDragKey.self] }
        set { self[AllowChildDragKey.self] = newValue }
    }
}

// RoundedCorner and cornerRadius extension (unchanged)
struct RoundedCorner: Shape {
    var radius: CGFloat = 0.0
    var corners: UIRectCorner = .allCorners
        
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}
