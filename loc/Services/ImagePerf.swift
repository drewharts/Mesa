//
//  ImagePerf.swift
//  loc
//
//  Single Responsibility: shared os_signpost / log handles for image and cover loading, so the
//  Instruments "Points of Interest"/signpost lane and Console show where time goes.
//

import Foundation
import os

enum ImagePerf {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "mesa"

    /// Signposter for image intervals ("imageLoad") and Explore cover intervals ("coverFetch").
    static let signposter = OSSignposter(subsystem: subsystem, category: "ImageLoad")

    /// Logger for cover timing lines (filter Console on category "ExploreCovers").
    static let logger = Logger(subsystem: subsystem, category: "ExploreCovers")
}
