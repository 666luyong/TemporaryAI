import SwiftUI
import WebKit

struct ChatWebView: NSViewControllerRepresentable {
    @ObservedObject var model: ChatWebViewModel

    func makeNSViewController(context: Context) -> ChatWebViewController {
        let vc = ChatWebViewController()
        vc.model = model
        return vc
    }

    func updateNSViewController(_ nsViewController: ChatWebViewController, context: Context) {
        // Update the view controller's model if it changed
        if nsViewController.model != model {
            nsViewController.model = model
            // Force view reload if model changed
            nsViewController.view = NSView() // Reset view to trigger loadView again ideally, or handle manually
            // Actually, best not to mess with view directly here unless we implement a proper update logic
        }
        
        // Failsafe: If the webview exists but hasn't loaded a URL yet, trigger it.
        // This fixes the bug where the initial tab might appear empty on app launch.
        if let webView = model.webView, webView.url == nil, !model.currentURL.contains("chatgpt.com") {
            DispatchQueue.main.async {
                model.loadInitialChat()
            }
        }
    }
}

final class ChatWebViewController: NSViewController {
    var model: ChatWebViewModel?

    override func loadView() {
        if let model = model {
            if model.webView == nil {
                model.webView = model.buildWebView()
                // Don't load request here immediately. Wait for viewDidAppear.
            }
            self.view = model.webView!
        } else {
            self.view = NSView()
        }
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        // Ensure we load content when the view actually appears on screen
        if let model = model, let webView = model.webView {
            if webView.url == nil && !model.currentURL.contains("chatgpt.com") {
                model.loadInitialChat()
            }
        }
    }
}
