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
    let minSheetHeight: CGFloat = 100 // <-- Ensure minimum height is set
    let maxSheetHeight: CGFloat
    @GestureState private var dragTranslation: CGFloat = 0 // <-- Use dragTranslation instead of dragOffset
    let content: Content

    init(sheetHeight: Binding<CGFloat>, maxSheetHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self._sheetHeight = sheetHeight
        self.maxSheetHeight = maxSheetHeight
        self.content = content()
    }

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 0) {
                // Drag Handle
                Capsule()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                // Content
                content
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            .frame(height: sheetHeight) // <-- Use sheetHeight directly
            .frame(maxWidth: .infinity)
            .background(Color.white)
            .cornerRadius(16, corners: [.topLeft, .topRight])
            .clipped()
            .gesture(
                DragGesture()
                    .updating($dragTranslation) { value, state, _ in
                        state = value.translation.height // <-- Track drag translation
                    }
                    .onEnded { value in
                        let newHeight = sheetHeight - value.translation.height
                        withAnimation {
                            if newHeight > (maxSheetHeight + minSheetHeight) / 2 {
                                sheetHeight = maxSheetHeight
                            } else {
                                sheetHeight = minSheetHeight
                            }
                        }
                    }
            )
            .onChange(of: dragTranslation) { value in
                let newHeight = sheetHeight - value // <-- Calculate new height
                if newHeight <= maxSheetHeight && newHeight >= minSheetHeight {
                    sheetHeight = newHeight // <-- Update sheetHeight directly
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

// Extension to round specific corners remains the same
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
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}
