//
//  ShareViewController.swift
//  Mesa Share
//
//  Created by Andrew Hartsfield II on 7/9/25.
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: SLComposeServiceViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        print("🔍 MesaShare: viewDidLoad called")
    }

    override func isContentValid() -> Bool {
        print("🔍 MesaShare: isContentValid called")
        return true
    }

    override func didSelectPost() {
        print("🔍 MesaShare: didSelectPost called")
        // Process the shared content
        if let item = extensionContext?.inputItems.first as? NSExtensionItem {
            print("🔍 MesaShare: Found input item")
            if let attachments = item.attachments {
                print("🔍 MesaShare: Found \(attachments.count) attachments")
                for (index, attachment) in attachments.enumerated() {
                    print("🔍 MesaShare: Processing attachment \(index)")
                    
                    // Handle URL sharing (TikTok shares video URLs)
                    if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                        print("🔍 MesaShare: Found URL attachment")
                        attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] (item, error) in
                            if let error = error {
                                print("❌ MesaShare: Error loading URL: \(error)")
                                self?.completeRequest()
                                return
                            }
                            if let url = item as? URL {
                                print("🔍 MesaShare: Loaded URL: \(url)")
                                self?.handleTikTokURL(url)
                            } else {
                                print("🔍 MesaShare: URL item is not a URL")
                                self?.completeRequest()
                            }
                        }
                        return
                    }
                    // Handle text sharing (TikTok sometimes shares as text)
                    else if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        print("🔍 MesaShare: Found text attachment")
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
                                } else {
                                    print("🔍 MesaShare: No TikTok URL found in text")
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

    override func configurationItems() -> [Any]! {
        return []
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
    
    private func storeSharedTikTokURL(_ urlString: String) {
        // Store the URL in UserDefaults for the main app to pick up
        if let sharedDefaults = UserDefaults(suiteName: "group.com.mesa.loc") {
            sharedDefaults.set(urlString, forKey: "sharedTikTokURL")
            sharedDefaults.synchronize()
            print("💾 Stored TikTok URL in shared storage")
        } else {
            // Fallback to regular UserDefaults
            UserDefaults.standard.set(urlString, forKey: "sharedTikTokURL")
            UserDefaults.standard.synchronize()
            print("💾 Stored TikTok URL in regular UserDefaults")
        }
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
