//
//  ImagePicker.swift
//  loc
//
//  Created by Andrew Hartsfield II on 1/6/25.
//


import SwiftUI
import PhotosUI

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var images: [UIImage]
    var selectionLimit: Int // 0 for multiple, 1 for single

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary

        // For multiple image selection (iOS 14+), set the limit
        if #available(iOS 14, *), selectionLimit != 1 {
            picker.sourceType = .photoLibrary
            picker.delegate = context.coordinator
        } else {
            picker.sourceType = .photoLibrary
            picker.delegate = context.coordinator
        }

        return picker
    }


    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No updates needed here
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let selectedImage = info[.originalImage] as? UIImage {
                if parent.selectionLimit == 1 {
                    // Single image selection: replace the array
                    parent.images = [selectedImage]
                } else {
                    // Multiple image selection: append to the array
                    parent.images.append(selectedImage)
                }
            }
            picker.dismiss(animated: true)
        }
    }
}
