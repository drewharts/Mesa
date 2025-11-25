//
//  ShareViewController.swift
//  MesaShare
//
//  Created by Andrew Hartsfield II on 7/9/25.
//  Refactored: Headless share extension for instant TikTok import
//

import UIKit
import UniformTypeIdentifiers

// MARK: - ShareViewController
/// A headless share extension that processes shared content immediately without showing any UI.
/// Supports TikTok URL imports and Mesa content sharing.
final class ShareViewController: UIViewController {
    
    // MARK: - Constants
    
    private enum Constants {
        enum TikTokDomains {
            static let all = ["tiktok.com", "vm.tiktok.com", "vt.tiktok.com"]
        }
    }
    
    // MARK: - Properties
    
    private var hasProcessedContent = false
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Make view invisible
        view.backgroundColor = .clear
        view.alpha = 0
    }
    
    /// IMPORTANT: Use viewWillAppear, NOT viewDidLoad
    /// The responder chain is not available in viewDidLoad
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure we only process once
        guard !hasProcessedContent else { return }
        hasProcessedContent = true
        
        // Keep view invisible
        view.alpha = 0
        view.isHidden = true
        
        // Process the shared content
        processSharedContent()
    }
    
    // MARK: - Content Processing
    
    private func processSharedContent() {
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments,
              let attachment = attachments.first else {
            print("🔗 [MesaShare] ❌ No extension items or attachments found")
            dismissExtension()
            return
        }
        
        print("🔗 [MesaShare] ℹ️ Processing attachment: \(attachment.registeredTypeIdentifiers)")
        
        // Priority 1: Handle URL attachments (TikTok shares video URLs)
        if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            loadURLAttachment(attachment)
            return
        }
        
        // Priority 2: Handle text attachments (TikTok sometimes shares as text with embedded URL)
        if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            loadTextAttachment(attachment)
            return
        }
        
        print("🔗 [MesaShare] ⚠️ No supported attachment type found")
        dismissExtension()
    }
    
    // MARK: - Attachment Loading
    
    private func loadURLAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🔗 [MesaShare] ❌ Failed to load URL: \(error.localizedDescription)")
                    self.dismissExtension()
                    return
                }
                
                guard let url = item as? URL else {
                    print("🔗 [MesaShare] ❌ Item is not a URL")
                    self.dismissExtension()
                    return
                }
                
                print("🔗 [MesaShare] ℹ️ Loaded URL: \(url.absoluteString)")
                
                if self.isTikTokURL(url) {
                    self.openMainApp(with: url)
                } else {
                    print("🔗 [MesaShare] ℹ️ Not a TikTok URL, dismissing")
                    self.dismissExtension()
                }
            }
        }
    }
    
    private func loadTextAttachment(_ attachment: NSItemProvider) {
        attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                if let error = error {
                    print("🔗 [MesaShare] ❌ Failed to load text: \(error.localizedDescription)")
                    self.dismissExtension()
                    return
                }
                
                guard let text = item as? String else {
                    print("🔗 [MesaShare] ❌ Item is not a string")
                    self.dismissExtension()
                    return
                }
                
                print("🔗 [MesaShare] ℹ️ Loaded text (\(text.count) chars)")
                
                if let tikTokURL = self.extractTikTokURL(from: text) {
                    self.openMainApp(with: tikTokURL)
                } else {
                    print("🔗 [MesaShare] ℹ️ No TikTok URL found in text")
                    self.dismissExtension()
                }
            }
        }
    }
    
    // MARK: - URL Detection
    
    private func isTikTokURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return Constants.TikTokDomains.all.contains { host.contains($0) }
    }
    
    private func extractTikTokURL(from text: String) -> URL? {
        let patterns = [
            #"https?://(?:www\.)?tiktok\.com/[^\s]+"#,
            #"https?://vm\.tiktok\.com/[^\s]+"#,
            #"https?://vt\.tiktok\.com/[^\s]+"#
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                continue
            }
            
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let matchRange = Range(match.range, in: text) {
                let urlString = String(text[matchRange])
                if let url = URL(string: urlString) {
                    return url
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Open Main App
    
    /// Opens the main app with the TikTok URL passed directly in the deep link.
    /// This avoids UserDefaults/App Group issues between extension and main app sandboxes.
    private func openMainApp(with tikTokURL: URL) {
        // URL-encode the TikTok URL and pass it directly in the deep link
        guard let encodedURL = tikTokURL.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            print("🔗 [MesaShare] ❌ Failed to encode TikTok URL")
            dismissExtension()
            return
        }
        
        // Use loc://share/tiktok?url=... format which DeepLinkManager already handles
        let deepLinkString = "loc://share/tiktok?url=\(encodedURL)"
        
        guard let deepLinkURL = URL(string: deepLinkString) else {
            print("🔗 [MesaShare] ❌ Failed to create deep link URL")
            dismissExtension()
            return
        }
        
        print("🔗 [MesaShare] ℹ️ Opening main app with deep link: \(deepLinkString)")
        
        // Walk up the responder chain to find UIApplication
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if let application = currentResponder as? UIApplication {
                print("🔗 [MesaShare] ✅ Found UIApplication in responder chain")
                
                // Use iOS 18+ compatible method
                application.open(deepLinkURL, options: [:]) { [weak self] success in
                    print("🔗 [MesaShare] \(success ? "✅" : "❌") App open result: \(success)")
                    self?.dismissExtension()
                }
                return
            }
            responder = currentResponder.next
        }
        
        print("🔗 [MesaShare] ❌ Could not find UIApplication in responder chain")
        dismissExtension()
    }
    
    // MARK: - Extension Lifecycle
    
    private func dismissExtension() {
        print("🔗 [MesaShare] ℹ️ Dismissing extension")
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
