//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Andrew Hartsfield II on 7/2/25.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func isContentValid() -> Bool {
        return true
    }

    override func didSelectPost() {
        // Process the shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            if let attachments = item.attachments {
                for attachment in attachments {
                    // Handle URL sharing (TikTok shares video URLs)
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                            if let url = item as? URL {
                                self?.handleTikTokURL(url)
                            } else {
                                self?.completeRequest()
                            }
                        }
                        return
                    }
                    // Handle text sharing (TikTok sometimes shares as text)
                    else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                            if let text = item as? String {
                                if let url = self?.extractTikTokURL(from: text) {
                                    self?.handleTikTokURL(url)
                                } else {
                                    self?.completeRequest()
                                }
                            } else {
                                self?.completeRequest()
                            }
                        }
                        return
                    }
                }
            }
        }
        
        // If no URL found, just complete
        completeRequest()
    }

    override func configurationItems() -> [Any]! {
        return []
    }
    
    private func handleTikTokURL(_ url: URL) {
        print("🎵 ShareExtension: Processing TikTok URL: \(url.absoluteString)")
        
        // Create deep link to main app
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "share"
        components.path = "/tiktok"
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString)
        ]
        
        guard let appURL = components.url else {
            print("❌ Failed to create app deep link")
            completeRequest()
            return
        }
        
        print("🔗 Opening app with URL: \(appURL.absoluteString)")
        
        // Open the main app
        DispatchQueue.main.async { [weak self] in
            self?.openURL(appURL) { success in
                print(success ? "✅ Successfully opened main app" : "❌ Failed to open main app")
                self?.completeRequest()
            }
        }
    }
    
    private func extractTikTokURL(from text: String) -> URL? {
        // Look for TikTok URLs in the text
        let patterns = [
            "https?://(?:www\\.)?tiktok\\.com/[^\\s]+",
            "https?://vm\\.tiktok\\.com/[^\\s]+",
            "https?://(?:www\\.)?tiktok\\.com/@[^/]+/video/\\d+"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
                if let match = matches.first {
                    let range = Range(match.range, in: text)!
                    let urlString = String(text[range])
                    return URL(string: urlString)
                }
            }
        }
        
        return nil
    }
    
    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        var responder: UIResponder? = self
        while responder != nil {
            if let application = responder as? UIApplication {
                if #available(iOS 10.0, *) {
                    application.open(url, options: [:]) { success in
                        completion(success)
                    }
                } else {
                    let success = application.openURL(url)
                    completion(success)
                }
                return
            }
            responder = responder?.next
        }
        completion(false)
    }
    
    private func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
