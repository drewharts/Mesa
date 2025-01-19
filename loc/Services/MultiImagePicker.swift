//
//  MultiImagePicker.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/18/25.
//


import SwiftUI
import PhotosUI

struct MultiImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var selectionLimit: Int // 0 for unlimited

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        // Configure the picker
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = selectionLimit // 0 is unlimited

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {
        // No updates needed
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: MultiImagePicker

        init(_ parent: MultiImagePicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            // Clear out the old images if you want fresh picks
            parent.images.removeAll()

            for result in results {
                // Each result has an itemProvider that can load a UIImage
                let itemProvider = result.itemProvider
                if itemProvider.canLoadObject(ofClass: UIImage.self) {
                    itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                self.parent.images.append(uiImage)
                            }
                        }
                    }
                }
            }
        }
    }
}
