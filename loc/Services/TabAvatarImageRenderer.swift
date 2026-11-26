//
//  TabAvatarImageRenderer.swift
//  loc
//
//  Pre-renders a profile photo into a small circular UIImage for the tab bar. SwiftUI's
//  tabItem only accepts already-sized images, and they must use .alwaysOriginal to keep color.
//

import UIKit

/// Renders circular avatar images sized for a tab bar item.
enum TabAvatarImageRenderer {
    static let diameter: CGFloat = 26
    private static let ringWidth: CGFloat = 2
    private static let ringColor = UIColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1)   // matches Color.mesaAccent

    /// Returns the photo cropped to a circle at tab-bar size, with an accent ring when `isSelected`.
    static func render(photo: UIImage, isSelected: Bool) -> UIImage {
        let size = CGSize(width: diameter, height: diameter)
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let bounds = CGRect(origin: .zero, size: size)
            let inset = isSelected ? ringWidth : 0
            let photoRect = bounds.insetBy(dx: inset, dy: inset)
            UIBezierPath(ovalIn: photoRect).addClip()
            photo.draw(in: aspectFillRect(for: photo.size, in: photoRect))
        }
        return isSelected ? addingRing(to: image) : image.withRenderingMode(.alwaysOriginal)
    }

    /// Draws the accent ring around an already-clipped avatar image.
    private static func addingRing(to image: UIImage) -> UIImage {
        let size = image.size
        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let ringed = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(at: .zero)
            let ringRect = CGRect(origin: .zero, size: size).insetBy(dx: ringWidth / 2, dy: ringWidth / 2)
            let ring = UIBezierPath(ovalIn: ringRect)
            ring.lineWidth = ringWidth
            ringColor.setStroke()
            ring.stroke()
        }
        return ringed.withRenderingMode(.alwaysOriginal)
    }

    /// Returns the rect that fills `container` with an image of `imageSize`, centered and cropped.
    private static func aspectFillRect(for imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }
        let scale = max(container.width / imageSize.width, container.height / imageSize.height)
        let width = imageSize.width * scale
        let height = imageSize.height * scale
        return CGRect(x: container.midX - width / 2, y: container.midY - height / 2, width: width, height: height)
    }
}
