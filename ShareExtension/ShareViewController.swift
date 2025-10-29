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

class ShareViewController: SLComposeServiceViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 MesaShare: viewDidLoad called")
        
        // Process the shared content immediately without showing UI
        processSharedContent()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Auto-trigger Post if we detect TikTok content
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.autoPostIfTikTok()
        }
    }
    
    private func autoPostIfTikTok() {
        // Check if we have TikTok content and auto-post
        if let item = extensionContext?.inputItems.first as? NSExtensionItem,
           let attachments = item.attachments {
            
            for attachment in attachments {
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                        if let url = item as? URL, self?.isTikTokURL(url) == true {
                            print("🔍 MesaShare: Auto-posting TikTok URL")
                            DispatchQueue.main.async {
                                self?.didSelectPost()
                            }
                        }
                    }
                    return
                } else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                        if let text = item as? String, self?.extractTikTokURL(from: text) != nil {
                            print("🔍 MesaShare: Auto-posting TikTok text")
                            DispatchQueue.main.async {
                                self?.didSelectPost()
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    // Override to make the Post button always enabled
    override var isContentValid: Bool {
        return true
    }
    
    // This is called when user taps Post
    override func didSelectPost() {
        print("🔍 MesaShare: didSelectPost called")
        processSharedContent()
    }
    
    private func processSharedContent() {
        print("🔍 MesaShare: Processing shared content automatically")
        
        // Process the shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            print("🔍 MesaShare: Found input item")
            if let attachments = item.attachments {
                print("🔍 MesaShare: Found \(attachments.count) attachments")
                for (index, attachment) in attachments.enumerated() {
                    print("🔍 MesaShare: Processing attachment \(index)")
                    
                    // Handle URL sharing (TikTok shares video URLs) - PRIORITY 1
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        print("🔍 MesaShare: Found URL attachment - processing immediately")
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                            if let error = error {
                                print("❌ MesaShare: Error loading URL: \(error)")
                                self?.completeRequest()
                                return
                            }
                            if let url = item as? URL {
                                print("🔍 MesaShare: Loaded URL: \(url)")
                                // Check if it's a TikTok URL and process immediately
                                if self?.isTikTokURL(url) == true {
                                    self?.handleTikTokURL(url)
                                } else {
                                    print("🔍 MesaShare: Not a TikTok URL, completing")
                                    self?.completeRequest()
                                }
                            } else {
                                print("🔍 MesaShare: URL item is not a URL")
                                self?.completeRequest()
                            }
                        }
                        return
                    }
                    // Handle text sharing (TikTok shares or Mesa list shares) - PRIORITY 2
                    else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        print("🔍 MesaShare: Found text attachment - processing immediately")
                        attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] (item, error) in
                            if let error = error {
                                print("❌ MesaShare: Error loading text: \(error)")
                                self?.completeRequest()
                                return
                            }
                            if let text = item as? String {
                                print("🔍 MesaShare: Loaded text: \(text)")
                                if let url = self?.extractTikTokURL(from: text) {
                                    self?.handleTikTokURL(url)
                                } else if self?.isMesaListShare(text) == true {
                                    self?.handleMesaListShare(text)
                                } else {
                                    print("🔍 MesaShare: No TikTok URL or Mesa list found in text")
                                    self?.completeRequest()
                                }
                            } else {
                                print("🔍 MesaShare: Text item is not a string")
                                self?.completeRequest()
                            }
                        }
                        return
                    } else {
                        print("🔍 MesaShare: Attachment \(index) has no matching type identifier")
                    }
                }
            } else {
                print("🔍 MesaShare: No attachments found")
            }
        } else {
            print("🔍 MesaShare: No input items found")
        }
        
        // If no URL found, just complete
        completeRequest()
    }
    
    private func handleTikTokURL(_ url: URL) {
        print("🎵 MesaShare: Processing TikTok URL: \(url.absoluteString)")
        
        // Method 1: Store URL in shared storage and launch app
        self.storeSharedTikTokURL(url.absoluteString)
        
        // Method 2: Try direct URL opening
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
        
        // Try opening with URL first
        DispatchQueue.main.async { [weak self] in
            self?.openURL(appURL) { success in
                if success {
                    print("✅ Successfully opened main app")
                    self?.completeRequest()
                } else {
                    print("❌ URL opening failed, trying NSUserActivity")
                    self?.openAppWithUserActivity(tikTokURL: url.absoluteString)
                }
            }
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
