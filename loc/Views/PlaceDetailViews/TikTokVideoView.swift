//
//  TikTokVideoView.swift
//  loc
//
//  Created by Mesa on 7/2/25.
//

import SwiftUI
import WebKit

struct TikTokVideoView: View {
    let tikTokVideo: TikTokVideo
    @State private var showingFullVideo = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Video thumbnail filling the whole square - Make entire area tappable
            Button(action: {
                openTikTokVideo()
            }) {
                AsyncImage(url: URL(string: tikTokVideo.thumbnailURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 150, height: 150)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 150, height: 150)
                        .cornerRadius(12)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Compact header with TikTok branding and author
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.pink)
                    .font(.caption)
                
                Text("@\(tikTokVideo.author.username)")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .fullScreenCover(isPresented: $showingFullVideo) {
            NavigationView {
                TikTokWebView(embedHTML: tikTokVideo.embedHTML, videoURL: tikTokVideo.url)
                    .navigationBarHidden(true)
                    .ignoresSafeArea()
            }
        }
    }
    
    private func openTikTokVideo() {
        if tryOpenInTikTokApp() { return }
        if tryOpenInBrowser() { return }
        // Final fallback to in-app webview
        showingFullVideo = true
    }
    
    private func tryOpenInTikTokApp() -> Bool {
        // Check if TikTok app is installed
        guard UIApplication.shared.canOpenURL(URL(string: "tiktok://")!) else {
            return false
        }
        
        // Try multiple URL formats for better compatibility
        let urlsToTry = createTikTokURLsToTry()
        
        for url in urlsToTry {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                return true
            }
        }
        
        return false
    }
    
    private func createTikTokURLsToTry() -> [URL] {
        var urls: [URL] = []
        
        // Try the original URL first
        if let originalURL = URL(string: tikTokVideo.url) {
            urls.append(originalURL)
        }
        
        // Try with different URL schemes if we can extract video ID
        if let videoId = extractVideoId(from: tikTokVideo.url) {
            // Try the tiktok:// scheme with video ID
            if let schemeURL = URL(string: "tiktok://video/\(videoId)") {
                urls.append(schemeURL)
            }
            
            // Try snssdk scheme (alternative TikTok scheme)
            if let snssdkURL = URL(string: "snssdk1233://video?id=\(videoId)") {
                urls.append(snssdkURL)
            }
        }
        
        return urls
    }
    
    private func tryOpenInBrowser() -> Bool {
        guard let webURL = URL(string: tikTokVideo.url),
              UIApplication.shared.canOpenURL(webURL) else {
            return false
        }
        UIApplication.shared.open(webURL)
        return true
    }
    
    private func createTikTokAppURL() -> URL? {
        // This method is no longer used but keeping for potential future use
        guard let videoId = extractVideoId(from: tikTokVideo.url) else {
            return nil
        }
        return URL(string: "tiktok://video/\(videoId)")
    }
    
    private func extractVideoId(from urlString: String) -> String? {
        if let shortId = extractFromShortURL(urlString) {
            return shortId
        }
        return extractFromRegularURL(urlString)
    }
    
    private func extractFromShortURL(_ urlString: String) -> String? {
        guard urlString.contains("/t/"),
              let range = urlString.range(of: "/t/") else {
            return nil
        }
        
        let afterT = String(urlString[range.upperBound...])
        
        // Clean up the video ID by removing trailing slashes and query parameters
        var videoId = afterT
        if let endRange = afterT.range(of: "/") {
            videoId = String(afterT[..<endRange.lowerBound])
        }
        
        // Remove query parameters
        videoId = videoId.components(separatedBy: "?").first ?? videoId
        
        // Remove any remaining special characters except alphanumeric
        videoId = videoId.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        
        return videoId.isEmpty ? nil : videoId
    }
    
    private func extractFromRegularURL(_ urlString: String) -> String? {
        guard urlString.contains("/video/"),
              let range = urlString.range(of: "/video/") else {
            return nil
        }
        
        let afterVideo = String(urlString[range.upperBound...])
        return afterVideo.components(separatedBy: "?").first?.components(separatedBy: "/").first
    }
}

struct TikTokWebView: UIViewRepresentable {
    let embedHTML: String
    let videoURL: String
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Create a full HTML page with the TikTok embed
        let fullHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
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
            </style>
        </head>
        <body>
            <button class="close-button" onclick="window.webkit.messageHandlers.closeVideo.postMessage('')">×</button>
            \(embedHTML)
            <script>
                // Prevent external navigation
                document.addEventListener('click', function(e) {
                    var target = e.target;
                    if (target.tagName === 'A' && target.href && target.href.includes('tiktok.com')) {
                        e.preventDefault();
                        return false;
                    }
                });
            </script>
        </body>
        </html>
        """
        
        webView.loadHTMLString(fullHTML, baseURL: URL(string: "https://www.tiktok.com"))
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: TikTokWebView
        
        init(_ parent: TikTokWebView) {
            self.parent = parent
            super.init()
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Add script message handler for close button
            webView.configuration.userContentController.add(self, name: "closeVideo")
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "closeVideo" {
                DispatchQueue.main.async {
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Allow initial load and TikTok embed scripts
            if url.absoluteString == "about:blank" || 
               url.host == "www.tiktok.com" ||
               url.absoluteString.contains("embed.js") ||
               url.absoluteString.contains("tiktok") {
                decisionHandler(.allow)
                return
            }
            
            // Block external navigation attempts
            if navigationAction.navigationType == .linkActivated {
                print("🚫 Blocked external navigation to: \(url.absoluteString)")
                decisionHandler(.cancel)
                return
            }
            
            decisionHandler(.allow)
        }
        
        deinit {
            // Clean up message handler
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct TikTokVideoView_Previews: PreviewProvider {
    static var previews: some View {
        TikTokVideoView(tikTokVideo: TikTokVideo(
            videoID: "sample123",
            url: "https://www.tiktok.com/t/ZP8hJe4ym/",
            title: "Amazing restaurant in NYC!",
            caption: "Check out this amazing Vietnamese restaurant in NYC! The food is incredible and authentic. #vietnamese #nyc #foodie #restaurant",
            embedHTML: "<blockquote class=\"tiktok-embed\">Sample embed</blockquote>",
            thumbnailURL: "https://example.com/thumbnail.jpg",
            author: TikTokAuthor(
                displayName: "Food Lover",
                url: "https://www.tiktok.com/@foodlover",
                username: "foodlover"
            ),
            hashtags: ["vietnamese", "nyc", "foodie", "restaurant"],
            createdAt: "2025-07-02T23:30:00Z"
        ))
        .padding()
    }
}