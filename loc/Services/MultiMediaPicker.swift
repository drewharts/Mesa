//
//  MultiMediaPicker.swift
//  loc
//
//  PHPicker that supports both images and videos with duration validation
//

import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

struct MultiMediaPicker: UIViewControllerRepresentable {
    @Binding var selectedMedia: [SelectedMediaItem]
    var selectionLimit: Int
    var maxVideoDuration: TimeInterval = 180

    /// Creates the PHPickerViewController configured for images and videos.
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = selectionLimit

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiMediaPicker

        init(_ parent: MultiMediaPicker) {
            self.parent = parent
        }

        /// Processes picked results, loading images and validating video durations.
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard !results.isEmpty else { return }

            parent.selectedMedia.removeAll()

            for result in results {
                let provider = result.itemProvider

                if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                    loadVideo(from: provider)
                } else if provider.canLoadObject(ofClass: UIImage.self) {
                    loadImage(from: provider)
                }
            }
        }

        /// Loads an image from the item provider.
        private func loadImage(from provider: NSItemProvider) {
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                guard let image = object as? UIImage else { return }

                let item = SelectedMediaItem(
                    type: .image,
                    image: image,
                    videoURL: nil,
                    thumbnail: nil,
                    duration: nil
                )
                DispatchQueue.main.async {
                    self.parent.selectedMedia.append(item)
                }
            }
        }

        /// Loads a video, validates its duration, and generates a thumbnail.
        private func loadVideo(from provider: NSItemProvider) {
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                guard let sourceURL = url else { return }

                // Copy to temp location since the provided URL is temporary
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")

                do {
                    try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                } catch {
                    print("[MultiMediaPicker] Failed to copy video: \(error)")
                    return
                }

                Task {
                    let asset = AVURLAsset(url: tempURL)
                    let durationResult = await self.loadDuration(from: asset)
                    let thumbnail = await self.generateThumbnail(from: asset)

                    let duration = durationResult ?? 0

                    guard duration <= self.parent.maxVideoDuration else {
                        print("[MultiMediaPicker] Video exceeds max duration: \(duration)s")
                        try? FileManager.default.removeItem(at: tempURL)
                        return
                    }

                    let item = SelectedMediaItem(
                        type: .video,
                        image: nil,
                        videoURL: tempURL,
                        thumbnail: thumbnail,
                        duration: duration
                    )

                    await MainActor.run {
                        self.parent.selectedMedia.append(item)
                    }
                }
            }
        }

        /// Loads the duration of an AVAsset.
        private func loadDuration(from asset: AVURLAsset) async -> TimeInterval? {
            do {
                let duration = try await asset.load(.duration)
                return CMTimeGetSeconds(duration)
            } catch {
                print("[MultiMediaPicker] Failed to load duration: \(error)")
                return nil
            }
        }

        /// Generates a thumbnail image from an AVAsset at 0.5 seconds.
        private func generateThumbnail(from asset: AVURLAsset) async -> UIImage? {
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)

            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            do {
                let (cgImage, _) = try await generator.image(at: time)
                return UIImage(cgImage: cgImage)
            } catch {
                print("[MultiMediaPicker] Failed to generate thumbnail: \(error)")
                return nil
            }
        }
    }
}
