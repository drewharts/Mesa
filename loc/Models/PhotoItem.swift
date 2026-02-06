//
//  PhotoItem.swift
//  loc
//
//  Model representing a photo URL for display in galleries.
//

import Foundation

/// Represents a photo URL for display. AsyncImage handles loading from the URL.
struct PhotoItem: Identifiable, Equatable {
    let id: String
    let url: String

    init(url: String) {
        self.id = url
        self.url = url
    }
}
