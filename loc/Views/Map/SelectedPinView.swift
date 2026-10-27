//
//  SelectedPinView.swift
//  loc
//
//  Highlighted look for the currently selected network/community pin on the Google map:
//  larger, wrapped in a glowing `mesaAccent` outline, with a subtle breathing pulse and a pop-in.
//  Built from whatever image the pin normally uses (emoji circle, baked photo composite, community
//  pin), so it works for every pin variant and keeps the same silhouette.
//

import UIKit

enum SelectedPinStyle {
    static let scale: CGFloat = 1.3
    static let ringThickness: CGFloat = 3.5
    static let margin: CGFloat = 14
    static let accent = UIColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1)   // matches Color.mesaAccent

    /// Returns `base` enlarged, outlined in the accent color, with an accent glow behind it.
    static func highlightedImage(from base: UIImage) -> UIImage {
        let size = base.size
        let outSize = CGSize(width: size.width * scale + margin * 2,
                             height: size.height * scale + margin * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: outSize, format: format).image { ctx in
            let baseRect = CGRect(x: margin, y: margin, width: size.width * scale, height: size.height * scale)
            let ringRect = baseRect.insetBy(dx: -ringThickness, dy: -ringThickness)
            // 1. accent silhouette slightly larger than the pin = uniform outline, with a soft glow.
            ctx.cgContext.saveGState()
            ctx.cgContext.setShadow(offset: .zero, blur: 10, color: accent.withAlphaComponent(0.75).cgColor)
            base.withTintColor(accent, renderingMode: .alwaysTemplate).draw(in: ringRect)
            ctx.cgContext.restoreGState()
            // 2. the pin itself on top.
            base.draw(in: baseRect)
        }
    }
}

/// Marker `iconView` for the selected pin. Animated, so the owning marker must have
/// `tracksViewChanges = true` (only one marker ever does).
final class SelectedPinView: UIView {
    /// Anchor that keeps the pin's visual bottom (network pins) or center (everything else) on the coordinate.
    let groundAnchor: CGPoint

    init(base: UIImage, bottomAnchored: Bool) {
        let image = SelectedPinStyle.highlightedImage(from: base)
        let size = image.size
        if bottomAnchored, base.size.height > 0 {
            // Same trick as unselected network pins: the visual bottom edge sits `renderPadding` above the image bottom.
            let contentBottom = SelectedPinStyle.margin + (base.size.height - MapMarkerImageFactory.renderPadding) * SelectedPinStyle.scale
            groundAnchor = CGPoint(x: 0.5, y: contentBottom / size.height)
        } else {
            groundAnchor = CGPoint(x: 0.5, y: 0.5)
        }
        super.init(frame: CGRect(origin: .zero, size: size))
        isUserInteractionEnabled = false
        let imageView = UIImageView(image: image)
        imageView.frame = bounds
        addSubview(imageView)
        animate(imageView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func animate(_ view: UIView) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        // Pop in…
        let pop = CASpringAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.6
        pop.toValue = 1.0
        pop.damping = 9
        pop.initialVelocity = 6
        pop.duration = pop.settlingDuration
        view.layer.add(pop, forKey: "pop")
        // …then a slow, subtle breathing pulse.
        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 1.0
        pulse.toValue = 1.06
        pulse.duration = 0.9
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        pulse.beginTime = CACurrentMediaTime() + pop.duration
        pulse.fillMode = .backwards
        view.layer.add(pulse, forKey: "pulse")
    }
}
