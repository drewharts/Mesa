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

class ShareViewController: UIViewController {
    
    private var hasProcessed = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 MesaShare: viewDidLoad called")
        
        // Make view completely transparent and hidden
        view.backgroundColor = .clear
        view.alpha = 0
        view.isHidden = true
        
        // Process immediately
        if !hasProcessed {
            hasProcessed = true
            processSharedItem()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Ensure UI is completely hidden
        view.alpha = 0
        view.isHidden = true
        view.backgroundColor = .clear
        
        // Process if not already processed
        if !hasProcessed {
            hasProcessed = true
            processSharedItem()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Force completion immediately
        DispatchQueue.main.async {
            self.forceCompleteForTikTok()
        }
    }
    
    private func forceCompleteForTikTok() {
        // Check if we have TikTok content and force complete
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments {
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL, self?.isTikTokURL(url) == true {
                            print("🔍 MesaShare: Force completing TikTok URL")
                            DispatchQueue.main.async {
                                self?.closeExtension()
                            }
                        }
                    }
                    return
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                        if let text = item as? String, self?.extractTikTokURL(from: text) != nil {
                            print("🔍 MesaShare: Force completing TikTok text")
                            DispatchQueue.main.async {
                                self?.closeExtension()
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func autoCompleteIfTikTok() {
        // Check if we have TikTok content and auto-complete
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments {
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL, self?.isTikTokURL(url) == true {
                            print("🔍 MesaShare: Auto-completing TikTok URL")
                            DispatchQueue.main.async {
                                self?.closeExtension()
                            }
                        }
                    }
                    return
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                        if let text = item as? String, self?.extractTikTokURL(from: text) != nil {
                            print("🔍 MesaShare: Auto-completing TikTok text")
                            DispatchQueue.main.async {
                                self?.closeExtension()
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
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
        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while responder != nil {
            if responder!.responds(to: selector) {
                responder!.perform(selector, with: url)
                break
            }
            responder = responder?.next
        }
        closeExtension()
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
        print("📋 MesaShare: Processing Mesa list share: \(text)")

        // Create deep link to main app for list sharing
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "share"
        components.path = "/list"
        components.queryItems = [
            URLQueryItem(name: "text", value: text)
        ]

        guard let appURL = components.url else {
            print("❌ Failed to create app deep link for list")
            completeRequest()
            return
        }

        print("🔗 Opening app with list share URL: \(appURL.absoluteString)")

        // Open the main app
        DispatchQueue.main.async { [weak self] in
            self?.openURL(appURL) { success in
                print(success ? "✅ Successfully opened main app for list share" : "❌ Failed to open main app for list share")
                self?.completeRequest()
            }
        }
    }
    
    private func handleMesaPlaceShare(_ text: String) {
        print("📍 MesaShare: Processing Mesa place share: \(text)")

        // Create deep link to main app for place sharing
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "share"
        components.path = "/place"
        components.queryItems = [
            URLQueryItem(name: "text", value: text)
        ]

        guard let appURL = components.url else {
            print("❌ Failed to create app deep link for place")
            completeRequest()
            return
        }

        print("🔗 Opening app with place share URL: \(appURL.absoluteString)")

        // Open the main app
        DispatchQueue.main.async { [weak self] in
            self?.openURL(appURL) { success in
                print(success ? "✅ Successfully opened main app for place share" : "❌ Failed to open main app for place share")
                self?.completeRequest()
            }
        }
    }
    
    private func storeSharedTikTokURL(_ urlString: String) {
        // Only use regular UserDefaults to avoid App Group errors
        UserDefaults.standard.set(urlString, forKey: "sharedTikTokURL")
        UserDefaults.standard.synchronize()
        print("💾 Stored TikTok URL in UserDefaults")
    }
    
    private func openAppWithUserActivity(tikTokURL: String) {
        // Method 2: Use NSUserActivity as fallback
        let userActivity = NSUserActivity(activityType: "com.mesa.share.tiktok")
        userActivity.title = "Share TikTok Video"
        userActivity.userInfo = ["tikTokURL": tikTokURL]
        userActivity.isEligibleForHandoff = true
        
        if let context = self.extensionContext {
            context.completeRequest(returningItems: [userActivity], completionHandler: nil)
        } else {
            completeRequest()
        }
    }
    
    private func openURL(_ url: URL, completion: @escaping (Bool) -> Void) {
        // Try multiple methods to open the URL
        
        // Method 1: Try extension context first
        if let context = self.extensionContext {
            context.open(url) { success in
                if success {
                    completion(true)
                } else {
                    print("❌ MesaShare: Extension context failed, trying UIApplication")
                    self.openURLWithUIApplication(url, completion: completion)
                }
            }
        } else {
            print("❌ MesaShare: No extension context, trying UIApplication")
            self.openURLWithUIApplication(url, completion: completion)
        }
    }
    
    private func openURLWithUIApplication(_ url: URL, completion: @escaping (Bool) -> Void) {
        // Method 2: Use UIApplication.shared.open (if available)
        DispatchQueue.main.async {
            if let application = UIApplication.value(forKeyPath: "sharedApplication") as? UIApplication {
                if application.canOpenURL(url) {
                    if #available(iOS 10.0, *) {
                        application.open(url, options: [:]) { success in
                            completion(success)
                        }
                    } else {
                        let success = application.openURL(url)
                        completion(success)
                    }
                } else {
                    print("❌ MesaShare: Cannot open URL: \(url)")
                    completion(false)
                }
            } else {
                print("❌ MesaShare: Cannot access UIApplication")
                completion(false)
            }
        }
    }
    
    private func completeRequest() {
        self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
