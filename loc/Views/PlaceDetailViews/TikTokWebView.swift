//
//  TikTokWebView.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import SwiftUI
import WebKit

struct TikTokWebView: UIViewRepresentable {
    let embedHTML: String
    let videoURL: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = createWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        setupWebView(webView, with: context)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        let fullHTML = createFullHTMLPage()
        webView.loadHTMLString(fullHTML, baseURL: URL(string: "https://www.tiktok.com"))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Setup Methods
    
    private func createWebViewConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        return configuration
    }
    
    private func setupWebView(_ webView: WKWebView, with context: Context) {
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
    }
    
    private func createFullHTMLPage() -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            \(createHTMLHead())
        </head>
        <body>
            \(createHTMLBody())
        </body>
        </html>
        """
    }
    
    private func createHTMLHead() -> String {
        return """
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
        <style>
            \(createHTMLStyles())
        </style>
        """
    }
    
    private func createHTMLStyles() -> String {
        return """
        body {
            margin: 0;
            padding: 0;
            background-color: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            font-family: -apple-system, BlinkMacSystemFont, sans-serif;
        }
        .tiktok-embed {
            max-width: 100% !important;
            width: 100% !important;
            margin: 0 auto;
        }
        .close-button {
            position: fixed;
            top: 50px;
            right: 20px;
            background: rgba(255, 255, 255, 0.8);
            border: none;
            border-radius: 20px;
            width: 40px;
            height: 40px;
            font-size: 20px;
            cursor: pointer;
            z-index: 9999;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        """
    }
    
    private func createHTMLBody() -> String {
        return """
        <button class="close-button" onclick="window.webkit.messageHandlers.closeVideo.postMessage('')">×</button>
        \(embedHTML)
        <script>
            \(createJavaScript())
        </script>
        """
    }
    
    private func createJavaScript() -> String {
        return """
        // Prevent external navigation
        document.addEventListener('click', function(e) {
            var target = e.target;
            if (target.tagName === 'A' && target.href && target.href.includes('tiktok.com')) {
                e.preventDefault();
                return false;
            }
        });
        """
    }
}

// MARK: - Coordinator

extension TikTokWebView {
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: TikTokWebView
        
        init(_ parent: TikTokWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            addScriptMessageHandler(to: webView)
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "closeVideo" {
                dismissVideo()
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let policy = determineNavigationPolicy(for: navigationAction)
            decisionHandler(policy)
        }
        
        // MARK: - Helper Methods
        
        private func addScriptMessageHandler(to webView: WKWebView) {
            webView.configuration.userContentController.add(self, name: "closeVideo")
        }
        
        private func dismissVideo() {
            DispatchQueue.main.async {
                self.parent.presentationMode.wrappedValue.dismiss()
            }
        }
        
        private func determineNavigationPolicy(for navigationAction: WKNavigationAction) -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .allow
            }
            
            if shouldAllowNavigation(to: url) {
                return .allow
            }
            
            if navigationAction.navigationType == .linkActivated {
                print("🚫 Blocked external navigation to: \(url.absoluteString)")
                return .cancel
            }
            
            return .allow
        }
        
        private func shouldAllowNavigation(to url: URL) -> Bool {
            let allowedPatterns = [
                "about:blank",
                "www.tiktok.com",
                "embed.js",
                "tiktok"
            ]
            
            return allowedPatterns.contains { pattern in
                url.absoluteString.contains(pattern) || url.host == pattern
            }
        }
        
        deinit {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
} 