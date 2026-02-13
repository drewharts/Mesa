//
//  SelectedMediaItem.swift
//  loc
//
//  Represents a media item picked from the user's photo library
//

import Foundation
import UIKit

struct SelectedMediaItem: Identifiable {
    let id = UUID()
    let type: PostMediaType
    let image: UIImage?
    let videoURL: URL?
    let thumbnail: UIImage?
    let duration: TimeInterval?
}
