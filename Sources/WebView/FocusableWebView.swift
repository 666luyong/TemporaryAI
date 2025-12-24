import WebKit

/// WKWebView that willingly takes key focus for keyboard input.
final class FocusableWebView: WKWebView {
    // Keep this to ensure it declares itself as focusable
    override var acceptsFirstResponder: Bool { true }
    
    // Remove other overrides to let standard AppKit behavior take over
}
