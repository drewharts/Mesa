//
//  WorldMapBannerView.swift
//  loc
//
//  Decorative world map banner displayed above profile pictures.
//  Visited countries are highlighted with a futuristic glow against a dark backdrop.
//

import SwiftUI

struct WorldMapBannerView: View {
    let visitedCountryCodes: Set<String>
    let height: CGFloat

    // MARK: - Color Palette
    private let oceanColor = Color(red: 0.08, green: 0.12, blue: 0.22)
    private let unvisitedColor = Color(red: 0.14, green: 0.18, blue: 0.28)
    private let unvisitedBorder = Color(red: 0.22, green: 0.26, blue: 0.38).opacity(0.5)
    private let visitedColor = Color(red: 0.2, green: 0.5, blue: 1.0)
    private let visitedGlow = Color(red: 0.3, green: 0.6, blue: 1.0).opacity(0.6)

    var body: some View {
        Canvas { context, size in
            // Draw dark ocean background
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(oceanColor))

            let service = WorldMapService.shared
            let transform = aspectFillTransform(canvasSize: size, mapAspect: service.aspectRatio)

            for shape in service.countryShapes {
                let isVisited = visitedCountryCodes.contains(shape.id)

                for cgPath in shape.paths {
                    let scaledPath = applyTransform(cgPath, transform)
                    let swiftPath = Path(scaledPath)

                    if isVisited {
                        // Glow layer behind visited countries
                        context.stroke(swiftPath, with: .color(visitedGlow), lineWidth: 2.5)
                        context.fill(swiftPath, with: .color(visitedColor))
                        context.stroke(swiftPath, with: .color(visitedGlow), lineWidth: 0.8)
                    } else {
                        context.fill(swiftPath, with: .color(unvisitedColor))
                        context.stroke(swiftPath, with: .color(unvisitedBorder), lineWidth: 0.5)
                    }
                }
            }
        }
        .frame(height: height)
        .clipped()
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.45),
                    .init(color: .white.opacity(0.05), location: 0.55),
                    .init(color: .white.opacity(0.12), location: 0.65),
                    .init(color: .white.opacity(0.25), location: 0.75),
                    .init(color: .white.opacity(0.5), location: 0.85),
                    .init(color: .white.opacity(0.8), location: 0.93),
                    .init(color: .white, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            WorldMapService.shared.loadIfNeeded()
        }
    }

    /// Computes an aspect-fill transform that scales the unit-square map to cover the canvas,
    /// then shifts it down so the northern hemisphere (US) sits closer to the bottom of the banner.
    private func aspectFillTransform(canvasSize: CGSize, mapAspect: CGFloat) -> CGAffineTransform {
        let canvasAspect = canvasSize.width / canvasSize.height
        // Shift map down so US is near bottom of banner (0 = centered, positive = down)
        let verticalShift: CGFloat = 0.12

        if canvasAspect > mapAspect {
            // Canvas is wider than map — fit to width, center vertically
            let mapHeight = canvasSize.width / mapAspect
            let offsetY = (canvasSize.height - mapHeight) / 2 + mapHeight * verticalShift
            return CGAffineTransform(scaleX: canvasSize.width, y: mapHeight)
                .concatenating(CGAffineTransform(translationX: 0, y: offsetY))
        } else {
            // Canvas is taller than map — fit to height, center horizontally
            let fitWidth = canvasSize.height * mapAspect
            let offsetX = (canvasSize.width - fitWidth) / 2
            let extraShift = canvasSize.height * verticalShift
            return CGAffineTransform(scaleX: fitWidth, y: canvasSize.height)
                .concatenating(CGAffineTransform(translationX: offsetX, y: extraShift))
        }
    }

    /// Applies a CGAffineTransform to a CGPath.
    private func applyTransform(_ path: CGPath, _ transform: CGAffineTransform) -> CGPath {
        var t = transform
        guard let result = path.copy(using: &t) else { return path }
        return result
    }
}
