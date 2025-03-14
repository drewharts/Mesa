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
    let minSheetHeight: CGFloat = 200
    let maxSheetHeight: CGFloat
    @GestureState private var dragTranslation: CGFloat = 0
    let content: Content

    init(
        isPresented: Binding<Bool>,
        sheetHeight: Binding<CGFloat>,
        maxSheetHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self._sheetHeight = sheetHeight
        self.maxSheetHeight = maxSheetHeight
        self.content = content()
    }

    // Computed property to determine if scrolling should be enabled
    private var isScrollingEnabled: Bool {
        sheetHeight == maxSheetHeight
    }

    var body: some View {
        VStack {
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
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.height
                    }
                    .onEnded { value in
                        let newHeight = sheetHeight - value.translation.height
                        let dismissalThreshold: CGFloat = 100
                        withAnimation {
                            if value.translation.height > dismissalThreshold {
                                isPresented = false
                            } else if newHeight > (maxSheetHeight + minSheetHeight) / 2 {
                                sheetHeight = maxSheetHeight
                            } else {
                                sheetHeight = minSheetHeight
                            }
                        }
                    }
            )
            .onChange(of: dragTranslation) { value in
                let newHeight = sheetHeight - value
                if newHeight <= maxSheetHeight && newHeight >= minSheetHeight {
                    sheetHeight = newHeight
                } else if newHeight > maxSheetHeight {
                    sheetHeight = maxSheetHeight
                } else if newHeight < minSheetHeight {
                    sheetHeight = minSheetHeight
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
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
