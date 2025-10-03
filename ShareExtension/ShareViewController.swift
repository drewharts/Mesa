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

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 ShareExtension: viewDidLoad called")
        
        // Process the shared content immediately without showing UI
        processSharedContent()
    }
    
    private func processSharedContent() {
        print("🔍 ShareExtension: didSelectPost called")
        // Process the shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            print("🔍 ShareExtension: Found input item")
            if let attachments = item.attachments {
                print("🔍 ShareExtension: Found \(attachments.count) attachments")
                for (index, attachment) in attachments.enumerated() {
                    print("🔍 ShareExtension: Processing attachment \(index)")
                    
                    // Handle URL sharing (TikTok shares video URLs)
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        print("🔍 ShareExtension: Found URL attachment")
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                            if let error = error {
                                print("❌ ShareExtension: Error loading URL: \(error)")
                                self?.completeRequest()
                                return
                            }
                            if let url = item as? URL {
                                print("🔍 ShareExtension: Loaded URL: \(url)")
                                self?.handleTikTokURL(url)
                            } else {
                                print("🔍 ShareExtension: URL item is not a URL")
                                self?.completeRequest()
                            }
                        }
                        return
                    }
                    // Handle text sharing (TikTok sometimes shares as text)
                    else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        print("🔍 ShareExtension: Found text attachment")
                        attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                            if let error = error {
                                print("❌ ShareExtension: Error loading text: \(error)")
                                self?.completeRequest()
                                return
                            }
                            if let text = item as? String {
                                print("🔍 ShareExtension: Loaded text: \(text)")
                                if let url = self?.extractTikTokURL(from: text) {
                                    self?.handleTikTokURL(url)
                                } else {
                                    print("🔍 ShareExtension: No TikTok URL found in text")
                                    self?.completeRequest()
                                }
                            } else {
                                print("🔍 ShareExtension: Text item is not a string")
                                self?.completeRequest()
                            }
                        }
                        return
                    } else {
                        print("🔍 ShareExtension: Attachment \(index) has no matching type identifier")
                    }
                }
            } else {
                print("🔍 ShareExtension: No attachments found")
            }
        } else {
            print("🔍 ShareExtension: No input items found")
        }
        
        // If no URL found, just complete
        completeRequest()
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
        // Use the extension context to open the URL
        if let context = self.extensionContext {
            context.open(url) { success in
                completion(success)
            }
        } else {
            completion(false)
        }
    }
    
    private func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
