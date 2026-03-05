//
//  GoogleMapsListExtractor.swift
//  loc
//
//  Created by Claude on 2/9/26.
//

import Foundation
import WebKit
import CoreLocation
import UIKit
import Combine

/// Extracts place data from Google Maps shared list URLs using a WKWebView.
/// The WebView is exposed as a published property so the UI can display it
/// during extraction — both for debugging and to provide a proper view hierarchy
/// for JavaScript execution.
@MainActor
class GoogleMapsListExtractor: NSObject, ObservableObject {

    // MARK: - Types

    /// Result of extracting places from a Google Maps list URL.
    struct ExtractionResult {
        let places: [GoogleMapsImportPlace]
        let listName: String?
    }

    /// Errors that can occur during extraction.
    enum ExtractionError: LocalizedError {
        case invalidURL
        case pageLoadFailed(String)
        case noPlacesFound
        case timeout
        case extractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Please enter a valid Google Maps list link."
            case .pageLoadFailed(let reason):
                return "Couldn't load the page: \(reason)"
            case .noPlacesFound:
                return "No places found in this list. Make sure the list is public and contains places."
            case .timeout:
                return "The page took too long to load. Please try again."
            case .extractionFailed(let reason):
                return "Couldn't extract places: \(reason)"
            }
        }
    }

    // MARK: - Published Properties

    /// The WKWebView used for rendering Google Maps pages.
    /// Exposed so the UI can embed it in the view hierarchy for both
    /// visibility (debugging) and proper JS execution.
    @Published var webView: WKWebView?

    /// Status text describing what the extractor is currently doing.
    @Published var statusText: String = ""

    // MARK: - Private Properties

    private var continuation: CheckedContinuation<ExtractionResult, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var extractionAttempt = 0
    private var didStartExtraction = false
    private static let maxExtractionAttempts = 4
    private static let totalTimeout: TimeInterval = 45
    private static let initialRenderDelay: TimeInterval = 5

    // MARK: - Public API

    /// Creates and configures the WKWebView. Call this before loadAndExtract
    /// so that SwiftUI has time to embed the WebView in the view hierarchy.
    func prepareWebView() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.navigationDelegate = self
        wv.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1"

        self.webView = wv
        statusText = "Preparing..."
    }

    /// Loads the Google Maps URL and extracts places from the rendered page.
    /// The WebView must already be prepared and embedded in the view hierarchy.
    func loadAndExtract(from urlString: String) async throws -> ExtractionResult {
        guard isValidGoogleMapsListURL(urlString) else {
            throw ExtractionError.invalidURL
        }

        guard let url = URL(string: urlString) else {
            throw ExtractionError.invalidURL
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            self.extractionAttempt = 0
            self.didStartExtraction = false
            startTimeout()
            statusText = "Loading Google Maps page..."
            print("[GoogleMapsExtractor] Loading URL: \(urlString)")
            webView?.load(URLRequest(url: url))
        }
    }

    // MARK: - Private Methods

    /// Validates that the URL is a Google Maps list link.
    private func isValidGoogleMapsListURL(_ urlString: String) -> Bool {
        let lowered = urlString.lowercased()
        return lowered.contains("google.com/maps") ||
               lowered.contains("maps.app.goo.gl") ||
               lowered.contains("goo.gl/maps")
    }

    /// Starts the overall timeout timer for the extraction process.
    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.totalTimeout * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.handleTimeout()
        }
    }

    /// Handles timeout by completing with an error.
    private func handleTimeout() {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        statusText = "Timed out"
        print("[GoogleMapsExtractor] Timed out after \(Self.totalTimeout)s")
        cleanup()
        continuation.resume(throwing: ExtractionError.timeout)
    }

    /// Cleans up the WebView and cancels timers.
    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        // Don't nil out webView here — the view may still be displaying it.
        // It will be released when the extractor is deallocated.
    }

    /// Schedules extraction after the page has had time to render its JavaScript.
    private func scheduleExtraction() {
        guard !didStartExtraction else { return }
        didStartExtraction = true

        Task { [weak self] in
            guard let self = self else { return }

            statusText = "Waiting for page to render..."
            print("[GoogleMapsExtractor] Waiting \(Self.initialRenderDelay)s for JS rendering...")
            try? await Task.sleep(nanoseconds: UInt64(Self.initialRenderDelay * 1_000_000_000))

            // Try to dismiss any consent banners
            await self.dismissConsentBanners()
            try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))

            // Scroll to trigger lazy loading
            statusText = "Scrolling to load all places..."
            await self.scrollToLoadAllPlaces()
            try? await Task.sleep(nanoseconds: UInt64(2.0 * 1_000_000_000))

            // Attempt extraction
            statusText = "Extracting place data..."
            await self.attemptExtraction()
        }
    }

    /// Tries to dismiss Google consent/cookie banners that may block content.
    private func dismissConsentBanners() async {
        let consentScript = """
        (function() {
            var buttons = document.querySelectorAll(
                'button[aria-label*="Accept"], button[aria-label*="Reject"], ' +
                'form[action*="consent"] button, [class*="consent"] button, ' +
                'button[jsname="b3VHJd"]'
            );
            for (var i = 0; i < buttons.length; i++) {
                var text = buttons[i].textContent.toLowerCase();
                if (text.includes('accept') || text.includes('reject all') || text.includes('agree')) {
                    buttons[i].click();
                    return 'clicked: ' + buttons[i].textContent;
                }
            }
            return 'no consent banner found';
        })();
        """

        if let result = try? await webView?.evaluateJavaScript(consentScript) as? String {
            print("[GoogleMapsExtractor] Consent: \(result)")
        }
    }

    /// Scrolls the WebView to trigger lazy loading of list items.
    private func scrollToLoadAllPlaces() async {
        let scrollScript = """
        (function() {
            var scrollables = document.querySelectorAll(
                '[role="main"], [role="feed"], .section-layout, ' +
                '[class*="section-scrollbox"], [class*="m6QErb"]'
            );
            var scrolled = 0;
            for (var i = 0; i < scrollables.length; i++) {
                scrollables[i].scrollTop = scrollables[i].scrollHeight;
                scrolled++;
            }
            window.scrollTo(0, document.body.scrollHeight);
            return scrolled;
        })();
        """

        if let count = try? await webView?.evaluateJavaScript(scrollScript) as? Int {
            print("[GoogleMapsExtractor] Scrolled \(count) containers")
        }

        try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
        _ = try? await webView?.evaluateJavaScript(scrollScript)
    }

    /// Attempts to extract place data from the page, retrying if needed.
    private func attemptExtraction() async {
        extractionAttempt += 1
        statusText = "Extraction attempt \(extractionAttempt) of \(Self.maxExtractionAttempts)..."
        print("[GoogleMapsExtractor] Extraction attempt \(extractionAttempt) of \(Self.maxExtractionAttempts)")

        await logPageState()

        let script = Self.extractionJavaScript

        do {
            guard let resultString = try await webView?.evaluateJavaScript(script) as? String,
                  let data = resultString.data(using: .utf8) else {
                print("[GoogleMapsExtractor] No result from JavaScript")
                retryOrFail(with: .noPlacesFound)
                return
            }
            handleExtractionResult(data)
        } catch {
            print("[GoogleMapsExtractor] JS error: \(error.localizedDescription)")
            retryOrFail(with: .extractionFailed(error.localizedDescription))
        }
    }

    /// Logs the current page URL and DOM size for debugging.
    private func logPageState() async {
        let debugScript = """
        (function() {
            return JSON.stringify({
                url: window.location.href,
                title: document.title,
                bodyLength: document.body ? document.body.innerHTML.length : 0,
                linkCount: document.querySelectorAll('a').length,
                placeLinks: document.querySelectorAll('a[href*="/maps/place/"]').length,
                ariaLabels: document.querySelectorAll('[aria-label]').length
            });
        })();
        """

        if let result = try? await webView?.evaluateJavaScript(debugScript) as? String {
            print("[GoogleMapsExtractor] Page state: \(result)")
            // Also update status text with key info
            if let data = result.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let placeLinks = json["placeLinks"] as? Int ?? 0
                let title = json["title"] as? String ?? ""
                statusText = "Page: \"\(title)\" — \(placeLinks) place links found"
            }
        }
    }

    /// The main JavaScript extraction script with multiple strategies.
    private static let extractionJavaScript = """
    (function() {
        var results = { places: [], listName: null, debug: '' };

        // Try to extract the list name
        var titleEl = document.querySelector('h1, h2, [role="heading"][aria-level="1"]');
        if (titleEl && titleEl.textContent.trim() !== 'Google Maps') {
            results.listName = titleEl.textContent.trim();
        }
        if (!results.listName) {
            var ogTitle = document.querySelector('meta[property="og:title"]');
            if (ogTitle && ogTitle.content !== 'Google Maps') {
                results.listName = ogTitle.content;
            }
        }

        var seenNames = new Set();

        // Strategy 1: Find place links with /maps/place/ in href
        var links = document.querySelectorAll('a[href*="/maps/place/"]');
        results.debug += 'S1:' + links.length + ' ';

        for (var i = 0; i < links.length; i++) {
            var href = links[i].href || '';
            var nameMatch = href.match(/\\/maps\\/place\\/([^/@]+)/);
            var coordMatch = href.match(/@(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)/);

            if (nameMatch) {
                var name = decodeURIComponent(nameMatch[1].replace(/\\+/g, ' '));
                if (seenNames.has(name)) continue;
                seenNames.add(name);

                var place = { name: name };
                if (coordMatch) {
                    place.latitude = parseFloat(coordMatch[1]);
                    place.longitude = parseFloat(coordMatch[2]);
                }

                var parent = links[i].closest('[role="listitem"], [data-index]');
                if (!parent) parent = links[i].parentElement;
                if (parent) {
                    var texts = parent.querySelectorAll('span, div');
                    for (var t = 0; t < texts.length; t++) {
                        var text = texts[t].textContent.trim();
                        if (text.length > 5 && text !== name && (text.includes(',') || /\\d/.test(text))) {
                            place.address = text;
                            break;
                        }
                    }
                }
                results.places.push(place);
            }
        }

        // Strategy 2: Find elements with aria-labels that look like place names
        if (results.places.length === 0) {
            var candidates = document.querySelectorAll(
                '[aria-label][role="link"], [aria-label][data-place-id], ' +
                '[role="listitem"] [aria-label], [data-item-id] [aria-label]'
            );
            results.debug += 'S2:' + candidates.length + ' ';

            for (var j = 0; j < candidates.length; j++) {
                var label = candidates[j].getAttribute('aria-label');
                if (label && label.length > 2 && label.length < 100 && !seenNames.has(label)) {
                    seenNames.add(label);
                    var placeObj = { name: label };

                    var nearbyLink = candidates[j].closest('a') || candidates[j].querySelector('a');
                    if (nearbyLink && nearbyLink.href) {
                        var cMatch = nearbyLink.href.match(/@(-?\\d+\\.\\d+),(-?\\d+\\.\\d+)/);
                        if (cMatch) {
                            placeObj.latitude = parseFloat(cMatch[1]);
                            placeObj.longitude = parseFloat(cMatch[2]);
                        }
                    }
                    results.places.push(placeObj);
                }
            }
        }

        // Strategy 3: Parse the raw page source for coordinate patterns
        if (results.places.length === 0) {
            var html = document.documentElement.innerHTML;
            var coordRegex = /\\[null,null,(-?\\d+\\.\\d{4,}),(-?\\d+\\.\\d{4,})\\]/g;
            var match;
            var coords = [];
            while ((match = coordRegex.exec(html)) !== null) {
                var lat = parseFloat(match[1]);
                var lng = parseFloat(match[2]);
                if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
                    coords.push({ latitude: lat, longitude: lng });
                }
            }

            var seen = new Set();
            for (var k = 0; k < coords.length; k++) {
                var key = coords[k].latitude.toFixed(4) + ',' + coords[k].longitude.toFixed(4);
                if (!seen.has(key)) {
                    seen.add(key);
                    results.places.push({
                        name: '',
                        latitude: coords[k].latitude,
                        longitude: coords[k].longitude
                    });
                }
            }
            results.debug += 'S3:' + results.places.length + ' ';
        }

        // Strategy 4: Look for place names in data-tooltip or title attributes
        if (results.places.length === 0) {
            var tooltips = document.querySelectorAll('[data-tooltip], [title]');
            results.debug += 'S4:' + tooltips.length + ' ';

            for (var m = 0; m < tooltips.length; m++) {
                var tip = tooltips[m].getAttribute('data-tooltip') || tooltips[m].getAttribute('title') || '';
                if (tip.length > 3 && tip.length < 80 && !seenNames.has(tip) &&
                    !tip.includes('Google') && !tip.includes('Sign in')) {
                    seenNames.add(tip);
                    results.places.push({ name: tip });
                }
            }
        }

        return JSON.stringify(results);
    })();
    """

    /// Parses the JSON result from JavaScript extraction.
    private func handleExtractionResult(_ data: Data) {
        do {
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let placesArray = json["places"] as? [[String: Any]] else {
                retryOrFail(with: .noPlacesFound)
                return
            }

            let debug = json["debug"] as? String ?? ""
            print("[GoogleMapsExtractor] Debug: \(debug)")

            let listName = json["listName"] as? String
            let places = parsePlaces(from: placesArray)

            print("[GoogleMapsExtractor] Found \(places.count) places")

            if places.isEmpty {
                retryOrFail(with: .noPlacesFound)
                return
            }

            completeSuccessfully(with: ExtractionResult(places: places, listName: listName))
        } catch {
            retryOrFail(with: .extractionFailed(error.localizedDescription))
        }
    }

    /// Converts raw JSON place dictionaries into GoogleMapsImportPlace objects.
    private func parsePlaces(from array: [[String: Any]]) -> [GoogleMapsImportPlace] {
        return array.compactMap { dict -> GoogleMapsImportPlace? in
            let name = dict["name"] as? String ?? ""

            var coordinate: CLLocationCoordinate2D?
            if let lat = dict["latitude"] as? Double, let lng = dict["longitude"] as? Double {
                coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }

            guard !name.isEmpty || coordinate != nil else { return nil }

            let address = dict["address"] as? String
            let displayName = name.isEmpty ? "Unknown Place" : name

            return GoogleMapsImportPlace(name: displayName, coordinate: coordinate, address: address)
        }
    }

    /// Retries extraction with a delay, or fails if max attempts reached.
    private func retryOrFail(with error: ExtractionError) {
        if extractionAttempt < Self.maxExtractionAttempts {
            statusText = "Retrying..."
            print("[GoogleMapsExtractor] Will retry after delay...")
            Task { [weak self] in
                let delay = Double(3 + (self?.extractionAttempt ?? 0) * 2)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                await self?.scrollToLoadAllPlaces()
                try? await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
                await self?.attemptExtraction()
            }
        } else {
            guard let continuation = self.continuation else { return }
            self.continuation = nil
            statusText = "Extraction failed"
            print("[GoogleMapsExtractor] All extraction attempts failed")
            cleanup()
            continuation.resume(throwing: error)
        }
    }

    /// Completes the extraction successfully.
    private func completeSuccessfully(with result: ExtractionResult) {
        guard let continuation = self.continuation else { return }
        self.continuation = nil
        statusText = "Found \(result.places.count) places!"
        print("[GoogleMapsExtractor] Extracted \(result.places.count) places")
        cleanup()
        continuation.resume(returning: result)
    }
}

// MARK: - WKNavigationDelegate

extension GoogleMapsListExtractor: WKNavigationDelegate {

    /// Called when the page finishes loading — schedules extraction after render delay.
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor [weak self] in
            print("[GoogleMapsExtractor] Page finished loading")
            self?.statusText = "Page loaded, waiting for content to render..."
            self?.scheduleExtraction()
        }
    }

    /// Handles server redirects (e.g., maps.app.goo.gl → full URL).
    nonisolated func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url {
            Task { @MainActor in
                print("[GoogleMapsExtractor] Navigating to: \(url.absoluteString.prefix(120))")
            }
        }
        decisionHandler(.allow)
    }

    /// Called when navigation fails — reports the error.
    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            if (error as NSError).code == NSURLErrorCancelled { return }

            print("[GoogleMapsExtractor] Navigation failed: \(error.localizedDescription)")
            guard let self = self, let continuation = self.continuation else { return }
            self.continuation = nil
            self.statusText = "Navigation failed"
            self.cleanup()
            continuation.resume(throwing: ExtractionError.pageLoadFailed(error.localizedDescription))
        }
    }

    /// Called when provisional navigation fails — reports the error.
    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor [weak self] in
            if (error as NSError).code == NSURLErrorCancelled { return }

            print("[GoogleMapsExtractor] Provisional navigation failed: \(error.localizedDescription)")
            guard let self = self, let continuation = self.continuation else { return }
            self.continuation = nil
            self.statusText = "Failed to load page"
            self.cleanup()
            continuation.resume(throwing: ExtractionError.pageLoadFailed(error.localizedDescription))
        }
    }
}
