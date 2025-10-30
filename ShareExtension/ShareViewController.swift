//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Andrew Hartsfield II on 7/2/25.
//

import UIKit
import Social
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide UI and process immediately
        hideUI()
        processSharedContent()
    }
    
    // MARK: - SLCompose Overrides
    override func isContentValid() -> Bool { return true }
    override func didSelectPost() { /* no-op */ }
    override func configurationItems() -> [Any]! { return [] }
    
    // MARK: - Core Logic
    private func hideUI() {
        textView.isHidden = true
        textView.alpha = 0
        textView.isUserInteractionEnabled = false
        placeholderLabel?.isHidden = true
        charactersRemainingLabel?.isHidden = true
        
        // Hide Post button
        if let postButton = navigationController?.navigationBar.topItem?.rightBarButtonItem?.customView as? UIButton {
            postButton.isHidden = true
        }
    }
    
    private func processSharedContent() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let provider = item.attachments?.first else {
            complete()
            return
        }
        
        // Handle URL (TikTok)
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (url, error) in
                guard let self = self, let url = url as? URL, error == nil, self.isTikTok(url) else {
                    self?.complete()
                    return
                }
                self.saveAndOpen(url: url)
            }
        }
        // Handle Text (TikTok URL or Mesa share)
        else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (text, error) in
                guard let self = self, let text = text as? String, error == nil else {
                    self?.complete()
                    return
                }
                
                if let tiktokURL = self.extractTikTokURL(from: text) {
                    self.saveAndOpen(url: tiktokURL)
                } else if self.isMesaShare(text) {
                    self.openMesaShare(text: text)
                } else {
                    self.complete()
                }
            }
        } else {
            complete()
        }
    }
    
    // MARK: - TikTok Processing
    private func isTikTok(_ url: URL) -> Bool {
        let s = url.absoluteString.lowercased()
        return s.contains("tiktok.com") || s.contains("vm.tiktok.com") || s.contains("vt.tiktok.com")
    }
    
    private func extractTikTokURL(from text: String) -> URL? {
        let patterns = ["https?://[^\\s]*tiktok\\.com[^\\s]*", "https?://vm\\.tiktok\\.com/[^\\s]+", "https?://vt\\.tiktok\\.com/[^\\s]+"]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                return URL(string: String(text[range]))
            }
        }
        return nil
    }
    
    private func saveAndOpen(url: URL) {
        // Save to App Group
        UserDefaults(suiteName: "group.com.mesa.loc")?.set(url.absoluteString, forKey: "sharedTikTokURL")
        
        // Open main app
        openURL(URL(string: "loc://tiktok-shared")!)
    }
    
    // MARK: - Mesa Share Processing
    private func isMesaShare(_ text: String) -> Bool {
        return text.contains("on Mesa!") || text.contains("Check out my list") || text.contains("Check out this place")
    }
    
    private func openMesaShare(text: String) {
        let path = text.contains("list") ? "/share/list" : "/share/place"
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "share"
        components.path = path
        components.queryItems = [URLQueryItem(name: "text", value: text)]
        
        if let url = components.url {
            openURL(url)
        } else {
            complete()
        }
    }
    
    // MARK: - Utilities
    private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        while responder != nil {
            if responder!.responds(to: #selector(UIApplication.openURL(_:))) {
                _ = responder!.perform(#selector(UIApplication.openURL(_:)), with: url)
                break
            }
            responder = responder?.next
        }
        complete()
    }
    
    private func complete() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}
