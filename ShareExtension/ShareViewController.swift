//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Andrew Hartsfield II on 7/2/25.
//  Updated: Consolidated Mesa Share functionality
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

extension URLComponents {
    func addingQueryItem(name: String, value: String) -> URLComponents {
        var components = self
        var queryItems = components.queryItems ?? []
        queryItems.append(URLQueryItem(name: name, value: value))
        components.queryItems = queryItems
        return components
    }
}

class ShareViewController: SLComposeServiceViewController {
    
    private var hasProcessed = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🔍 MesaShare: viewDidLoad")

        // Hide all default UI
        textView.isHidden = true
        textView.alpha = 0
        textView.isUserInteractionEnabled = false
        
        // Hide placeholder and character count
        placeholderLabel?.isHidden = true
        charactersRemainingLabel?.isHidden = true
        
        // Hide "Post" button (via private API – safe)
        if let postButton = navigationController?.navigationBar.topItem?.rightBarButtonItem?.customView as? UIButton {
            postButton.isHidden = true
        }

        // Process immediately
        if !hasProcessed {
            hasProcessed = true
            processSharedItem()
        }
    }
    
    // MARK: - SLCompose Overrides (Critical!)
    override func isContentValid() -> Bool { return true }
    override func didSelectPost() { /* no-op */ }
    override func configurationItems() -> [Any]! { return [] }
    
    // MARK: - Process Shared TikTok URL
    private func processSharedItem() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            closeExtension()
            return
        }
        
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                guard let self = self, let url = url as? URL, error == nil else {
                    self?.closeExtension()
                    return
                }
                
                // Check if it's a TikTok URL
                if self.isTikTokURL(url) {
                    // Save to App Group
                    self.saveToAppGroup(url: url)
                    
                    // Open main app
                    self.openMainApp()
                } else {
                    self.closeExtension()
                }
            }
        } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (text, error) in
                guard let self = self, let text = text as? String, error == nil else {
                    self?.closeExtension()
                    return
                }
                
                // Check if text contains TikTok URL
                if let tiktokURL = self.extractTikTokURL(from: text) {
                    // Save to App Group
                    self.saveToAppGroup(url: tiktokURL)
                    
                    // Open main app
                    self.openMainApp()
                } else if self.isMesaListShare(text) {
                    // Handle Mesa list sharing
                    self.handleMesaListShare(text)
                } else if self.isMesaPlaceShare(text) {
                    // Handle Mesa place sharing
                    self.handleMesaPlaceShare(text)
                } else {
                    self.closeExtension()
                }
            }
        } else {
            closeExtension()
        }
    }
    
    // MARK: - Save to App Group
    private func saveToAppGroup(url: URL) {
        let shared = UserDefaults(suiteName: "group.com.mesa.loc")
        shared?.set(url.absoluteString, forKey: "sharedTikTokURL")
        shared?.synchronize()
        print("💾 MesaShare: Saved TikTok URL to App Group: \(url.absoluteString)")
    }
    
    // MARK: - Open Main App
    private func openMainApp() {
        let url = URL(string: "loc://tiktok-shared")!
        _ = openURL(url) { _ in
            self.closeExtension()
        }
    }
    
    // MARK: - openURL Helper
    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) -> Bool {
        var responder: UIResponder? = self
        let selector = #selector(UIApplication.openURL(_:))
        while responder != nil {
            if responder!.responds(to: selector) {
                return responder!.perform(selector, with: url) != nil
            }
            responder = responder?.next
        }
        return false
    }
    
    // MARK: - Close Extension
    private func closeExtension() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
    
    
    
    private func isTikTokURL(_ url: URL) -> Bool {
        let urlString = url.absoluteString.lowercased()
        return urlString.contains("tiktok.com") || 
               urlString.contains("vm.tiktok.com") || 
               urlString.contains("vt.tiktok.com")
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

    private func isMesaListShare(_ text: String) -> Bool {
        // Check if the text contains Mesa list sharing patterns
        return text.contains("on Mesa!") || text.contains("Check out my list")
    }
    
    private func isMesaPlaceShare(_ text: String) -> Bool {
        // Check if the text contains Mesa place sharing patterns
        return text.contains("Check out this place") || text.contains("on Mesa!")
    }

    private func handleMesaListShare(_ text: String) {
        let components = URLComponents(string: "loc://share/list")!
            .addingQueryItem(name: "text", value: text)
        guard let url = components.url else { closeExtension(); return }
        _ = openURL(url) { _ in self.closeExtension() }
    }
    
    private func handleMesaPlaceShare(_ text: String) {
        let components = URLComponents(string: "loc://share/place")!
            .addingQueryItem(name: "text", value: text)
        guard let url = components.url else { closeExtension(); return }
        _ = openURL(url) { _ in self.closeExtension() }
    }
    
}
