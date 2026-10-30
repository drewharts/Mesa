//
//  ProfilePhotoCropView.swift
//  loc
//
//  Shared circular crop / position editor for profile photos (onboarding, profile, edit profile).
//  Pinch to zoom, drag to move. The original photo is kept on-device so the crop can be
//  re-adjusted later without picking the photo again.
//

import SwiftUI
import UIKit

// MARK: - Request

struct ProfilePhotoEditRequest: Identifiable {
    let id = UUID()
    let image: UIImage
    let isNewPhoto: Bool
    /// True when `image` is the stored original, so the last zoom/position can be restored.
    var restoreSavedState: Bool = false
}

// MARK: - Original photo store (device-local, no backend)

enum ProfilePhotoOriginalStore {
    private static var dir: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("ProfilePhotoOriginals", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func fileURL(_ userId: String) -> URL {
        dir.appendingPathComponent("\(userId.lowercased()).jpg")
    }

    static func save(_ image: UIImage, userId: String) {
        guard !userId.isEmpty else { return }
        let resized = image.normalizedForCrop(maxDimension: 2400)
        guard let data = resized.jpegData(compressionQuality: 0.9) else { return }
        try? data.write(to: fileURL(userId), options: .atomic)
    }

    static func load(userId: String) -> UIImage? {
        guard !userId.isEmpty, let data = try? Data(contentsOf: fileURL(userId)) else { return nil }
        return UIImage(data: data)
    }

    // Last crop state, so re-adjusting starts where the user left off.
    static func saveState(zoom: CGFloat, offset: CGSize, userId: String) {
        UserDefaults.standard.set([Double(zoom), Double(offset.width), Double(offset.height)],
                                  forKey: "profilePhotoCropState.\(userId.lowercased())")
    }

    static func loadState(userId: String) -> (zoom: CGFloat, offset: CGSize)? {
        guard let a = UserDefaults.standard.array(forKey: "profilePhotoCropState.\(userId.lowercased())") as? [Double],
              a.count == 3 else { return nil }
        return (CGFloat(a[0]), CGSize(width: a[1], height: a[2]))
    }
}

extension UIImage {
    /// Returns an `.up`-oriented copy, downscaled so the longest side is at most `maxDimension`.
    func normalizedForCrop(maxDimension: CGFloat = 3000) -> UIImage {
        let longest = max(size.width, size.height)
        let factor = longest > maxDimension ? maxDimension / longest : 1
        if imageOrientation == .up && factor == 1 { return self }
        let target = CGSize(width: (size.width * factor).rounded(), height: (size.height * factor).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Crop view

struct ProfilePhotoCropView: View {
    let image: UIImage
    var isNewPhoto: Bool = true
    var source: String
    /// Normalized starting state (offset is a fraction of the circle diameter).
    var initialZoom: CGFloat = 1
    var initialOffset: CGSize = .zero
    var onChooseAnother: (() -> Void)? = nil
    var onCancel: () -> Void
    /// (cropped square image, normalized zoom, normalized offset)
    var onDone: (UIImage, CGFloat, CGSize) -> Void

    @State private var baseImage: UIImage = UIImage()
    @State private var zoom: CGFloat = 1
    @State private var lastZoom: CGFloat = 1
    @State private var offset: CGSize = .zero      // points, relative to circle center
    @State private var lastOffset: CGSize = .zero
    @State private var diameter: CGFloat = 300
    @State private var didSetup = false

    private let maxZoom: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let d = min(geo.size.width - 48, geo.size.height - 260, 360)
            ZStack {
                Color.black.ignoresSafeArea()

                cropImage(d: d)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .contentShape(Rectangle())
                    .gesture(dragGesture(d: d).simultaneously(with: pinchGesture(d: d)))

                // Dim outside the circle
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .mask(
                        ZStack {
                            Rectangle()
                            Circle().frame(width: d, height: d).blendMode(.destinationOut)
                        }
                        .compositingGroup()
                    )
                    .allowsHitTesting(false)
                    .ignoresSafeArea()

                Circle()
                    .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: d, height: d)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    Text("Move and Scale")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    Text("Pinch to zoom · drag to position")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 4)
                    Spacer()
                    bottomBar
                }
            }
            .onAppear {
                diameter = d
                setupIfNeeded(d: d)
            }
            .onChange(of: d) { _, newD in
                // Keep the same visual crop if layout changes.
                let ratio = newD / max(diameter, 1)
                offset = CGSize(width: offset.width * ratio, height: offset.height * ratio)
                lastOffset = offset
                diameter = newD
            }
        }
        .statusBarHidden()
        .analyticsScreen("Profile Photo Crop")
    }

    private var bottomBar: some View {
        HStack {
            Button("Cancel", action: onCancel)
                .font(.system(size: 17))
                .foregroundColor(.white)
            Spacer()
            if let onChooseAnother {
                Button {
                    onChooseAnother()
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.white.opacity(0.15)))
                }
                .accessibilityLabel("Choose another photo")
                Spacer()
            }
            Button {
                finish()
            } label: {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .frame(height: 40)
                    .background(Capsule().fill(Color.white))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    // MARK: Rendering

    private func baseScale(d: CGFloat) -> CGFloat {
        let s = baseImage.size
        guard s.width > 0, s.height > 0 else { return 1 }
        return d / min(s.width, s.height)
    }

    private func cropImage(d: CGFloat) -> some View {
        let s = baseImage.size
        let scale = baseScale(d: d) * zoom
        return Image(uiImage: baseImage)
            .resizable()
            .frame(width: s.width * scale, height: s.height * scale)
            .offset(offset)
    }

    // MARK: Gestures

    private func clamp(_ o: CGSize, zoom z: CGFloat, d: CGFloat) -> CGSize {
        let s = baseImage.size
        let scale = baseScale(d: d) * z
        let maxX = max(0, (s.width * scale - d) / 2)
        let maxY = max(0, (s.height * scale - d) / 2)
        return CGSize(width: min(max(o.width, -maxX), maxX),
                      height: min(max(o.height, -maxY), maxY))
    }

    private func dragGesture(d: CGFloat) -> some Gesture {
        DragGesture()
            .onChanged { v in
                let proposed = CGSize(width: lastOffset.width + v.translation.width,
                                      height: lastOffset.height + v.translation.height)
                offset = clamp(proposed, zoom: zoom, d: d)
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func pinchGesture(d: CGFloat) -> some Gesture {
        MagnifyGesture()
            .onChanged { v in
                let newZoom = min(max(lastZoom * v.magnification, 1), maxZoom)
                // Scale offset with zoom so the point under the circle center stays put.
                let ratio = newZoom / max(zoom, 0.0001)
                zoom = newZoom
                offset = clamp(CGSize(width: offset.width * ratio, height: offset.height * ratio), zoom: newZoom, d: d)
            }
            .onEnded { _ in
                lastZoom = zoom
                lastOffset = offset
            }
    }

    private func setupIfNeeded(d: CGFloat) {
        guard !didSetup else { return }
        didSetup = true
        baseImage = image.normalizedForCrop()
        zoom = min(max(initialZoom, 1), maxZoom)
        lastZoom = zoom
        offset = clamp(CGSize(width: initialOffset.width * d, height: initialOffset.height * d), zoom: zoom, d: d)
        lastOffset = offset
    }

    // MARK: Output

    private func finish() {
        let d = diameter
        let s = baseImage.size
        let scale = baseScale(d: d) * zoom
        let side = d / scale
        let cx = s.width / 2 - offset.width / scale
        let cy = s.height / 2 - offset.height / scale
        let rect = CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)

        let outSide = min(1024, max(1, side.rounded()))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let cropped = UIGraphicsImageRenderer(size: CGSize(width: outSide, height: outSide), format: format).image { _ in
            let k = outSide / side
            baseImage.draw(in: CGRect(x: -rect.minX * k, y: -rect.minY * k, width: s.width * k, height: s.height * k))
        }

        let normOffset = CGSize(width: offset.width / max(d, 1), height: offset.height / max(d, 1))
        Analytics.track(.profilePhotoCropped, [
            "source": source,
            "is_new_photo": isNewPhoto,
            "zoom": Double((zoom * 100).rounded() / 100),
            "moved": offset != .zero
        ])
        onDone(cropped, zoom, normOffset)
    }
}

// MARK: - Shared picker → crop flow

/// Attach to any view that lets the user set their profile photo. Set `showPicker` to pick a new
/// photo, or set `editRequest` to re-adjust an existing one.
struct ProfilePhotoEditorModifier: ViewModifier {
    @Binding var showPicker: Bool
    @Binding var editRequest: ProfilePhotoEditRequest?
    let source: String
    let userId: String?
    /// (cropped, original)
    let onCropped: (UIImage, UIImage) -> Void

    @State private var picked: [UIImage] = []
    @State private var reopenPickerAfterCrop = false

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPicker, onDismiss: {
                if let img = picked.first {
                    picked = []
                    editRequest = ProfilePhotoEditRequest(image: img, isNewPhoto: true)
                }
            }) {
                ImagePicker(images: $picked, selectionLimit: 1)
                    .ignoresSafeArea()
            }
            .fullScreenCover(item: $editRequest, onDismiss: {
                if reopenPickerAfterCrop {
                    reopenPickerAfterCrop = false
                    showPicker = true
                }
            }) { req in
                let state = (req.restoreSavedState ? userId.flatMap { ProfilePhotoOriginalStore.loadState(userId: $0) } : nil)
                ProfilePhotoCropView(
                    image: req.image,
                    isNewPhoto: req.isNewPhoto,
                    source: source,
                    initialZoom: state?.zoom ?? 1,
                    initialOffset: state?.offset ?? .zero,
                    onChooseAnother: {
                        reopenPickerAfterCrop = true
                        editRequest = nil
                    },
                    onCancel: { editRequest = nil },
                    onDone: { cropped, zoom, offset in
                        if let userId {
                            ProfilePhotoOriginalStore.saveState(zoom: zoom, offset: offset, userId: userId)
                        }
                        onCropped(cropped, req.image)
                        editRequest = nil
                    }
                )
            }
    }
}

extension View {
    func profilePhotoEditor(showPicker: Binding<Bool>,
                            editRequest: Binding<ProfilePhotoEditRequest?>,
                            source: String,
                            userId: String?,
                            onCropped: @escaping (UIImage, UIImage) -> Void) -> some View {
        modifier(ProfilePhotoEditorModifier(showPicker: showPicker, editRequest: editRequest,
                                            source: source, userId: userId, onCropped: onCropped))
    }
}
