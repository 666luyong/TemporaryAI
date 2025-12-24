import SwiftUI
import WebKit
import AppKit

// Keep for internal blocking feedback (e.g. network errors)
struct BlockedNavigation: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let reason: String
}

final class ChatWebViewModel: NSObject, ObservableObject {
    weak var webView: WKWebView?
    @Published var blockedNavigation: BlockedNavigation?
    @Published var sessionSubtitle: String = "未登录" {
        didSet {
            onTitleChange?(sessionSubtitle)
        }
    }
    @Published var currentURL: String = ""
    
    var onTitleChange: ((String) -> Void)?
    
    let aiType: AIType
    private let policyEngine: NavigationPolicyEngine
    private let settings = SettingsManager.shared
    private var urlObservation: NSKeyValueObservation?
    private var hasCompletedFirstLoad = false
    private var historyBlockRuleAdded = false
    
    var isTemporaryModeLocked: Bool { true }

    init(aiType: AIType) {
        self.aiType = aiType
        self.policyEngine = NavigationPolicyEngine(aiType: aiType)
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleForceReload), name: Notification.Name("ForceReloadTempChat"), object: nil)
        
        // Listen for UserDefaults changes (covers @AppStorage updates from Settings)
        NotificationCenter.default.addObserver(self, selector: #selector(handleUserDefaultsChange), name: UserDefaults.didChangeNotification, object: nil)
    }
    
    @objc private func handleUserDefaultsChange() {
        let enabled = UserDefaults.standard.bool(forKey: "allowWebInspector")
        updateWebInspector(enabled: enabled)
    }

    private func updateWebInspector(enabled: Bool) {
        guard let webView = webView else { return }
        let current = webView.configuration.preferences.value(forKey: "developerExtrasEnabled") as? Bool ?? false
        if current != enabled {
            webView.configuration.preferences.setValue(enabled, forKey: "developerExtrasEnabled")
        }
    }

    var showingPlaceholder: Bool {
        blockedNavigation != nil || !hasCompletedFirstLoad
    }

    var placeholderTitle: String {
        blockedNavigation == nil ? aiType.rawValue : "已拦截页面跳转"
    }

    var placeholderSubtitle: String {
        blockedNavigation == nil ? "加载中" : "显示拦截提示 Banner"
    }
    
    @objc private func handleForceReload() {
        loadInitialChat()
    }

    private func checkFirstLoadCompletion() {
        guard let url = webView?.url else { return }
        
        let targetHost = aiType == .chatGPT ? "chatgpt.com" : "gemini.google.com"
        
        // As soon as we are on the target domain, dismiss the placeholder
        if !hasCompletedFirstLoad && url.host?.contains(targetHost) == true {
            DispatchQueue.main.async {
                self.hasCompletedFirstLoad = true
                self.sessionSubtitle = "已加载" + self.aiType.rawValue
                // Force object update to ensure View picks it up
                self.objectWillChange.send()
            }
        }
    }

    func buildWebView() -> WKWebView {
        let userContentController = WKUserContentController()
        
        // Always add script for debugging "No Red Dot" issue
        // Now using decoupled manager
        userContentController.addUserScript(UserScriptManager.hideSidebarScript(for: aiType))
        
        // Inject Global Script if present
        if let globalScript = UserScriptManager.globalScript() {
            userContentController.addUserScript(globalScript)
        }

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        
        // Settings: Web Inspector
        let allowWebInspector = UserDefaults.standard.bool(forKey: "allowWebInspector")
        if allowWebInspector {
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")
        }
        
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        if aiType == .chatGPT {
             addHistoryBlockRules(to: userContentController)
        }

        let webView = FocusableWebView(frame: .zero, configuration: configuration)
        
        // Settings: Custom User Agent
        if !settings.customUserAgent.isEmpty {
            webView.customUserAgent = settings.customUserAgent
        } else {
            // Use default specific for macOS to prevent mobile view issues
            webView.customUserAgent = settings.defaultUserAgent
        }
        
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false

        // KVO for SPA routing changes
        urlObservation = webView.observe(\.url, options: .new) { [weak self] webView, change in
            guard let self = self, let url = webView.url else { return }
            self.currentURL = url.absoluteString
            
            self.checkFirstLoadCompletion()
            
            // CRITICAL FIX: Ignore KVO for external domains.
            
            if self.policyEngine.isExternalDomain(url) {
                return
            }
            
            let context = NavigationContext(
                url: url,
                isMainFrame: true,
                navigationType: .other,
                isUserInitiated: false
            )
            
            let decision = self.policyEngine.decidePolicy(for: context)
            if case .forceTempChat = decision {
                self.loadInitialChat()
            }
        }

        return webView
    }

    func loadInitialChat() {
        guard let webView else { return }
        blockedNavigation = nil
        let request = URLRequest(url: aiType.url)
        webView.load(request)
        focusWebView()
    }

    func reload() {
        if blockedNavigation != nil {
            loadInitialChat()
        } else {
            webView?.reload()
        }
    }

    func startNewChat() {
        loadInitialChat()
    }

    func goHome() {
        loadInitialChat()
    }

    func reopenLastAllowed() {
        if let webView, webView.canGoBack {
            webView.goBack()
        } else {
            loadInitialChat()
        }
    }

    func dismissBanner() {
        blockedNavigation = nil
    }

    func focusWebView() {
        guard let webView else { return }
        webView.window?.makeFirstResponder(webView)
    }

    private func addHistoryBlockRules(to controller: WKUserContentController) {
        guard !historyBlockRuleAdded else { return }
        guard let store = WKContentRuleListStore.default() else {
            historyBlockRuleAdded = true
            return
        }

        store.compileContentRuleList(
            forIdentifier: "HistoryBlocker",
            encodedContentRuleList: Self.historyBlockRuleJSON
        ) { [weak controller] ruleList, _ in
            if let ruleList {
                controller?.add(ruleList)
            }
        }
        historyBlockRuleAdded = true
    }
}

// MARK: - Navigation Delegate

extension ChatWebViewModel: WKNavigationDelegate, WKUIDelegate {
    // Called when content starts arriving (earlier than didFinish)
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        checkFirstLoadCompletion()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        checkFirstLoadCompletion()
        
        // sessionSubtitle and currentURL are now handled by checkFirstLoadCompletion
        // But we keep this for redundancy if URL changed later
        if hasCompletedFirstLoad {
             currentURL = webView.url?.absoluteString ?? ""
        }
        
        // DEBUG: Force re-inject every time, no checks
        webView.evaluateJavaScript(UserScriptManager.hideSidebarScript(for: aiType).source) { _, error in
            if let error = error {
                print("Sidebar script injection error: \(error.localizedDescription)")
            }
        }
        
        focusWebView()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled {
            blockedNavigation = BlockedNavigation(url: webView.url ?? aiType.url, reason: error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        let context = NavigationContext(
            url: url,
            isMainFrame: navigationAction.targetFrame?.isMainFrame ?? true,
            navigationType: navigationAction.navigationType,
            isUserInitiated: navigationAction.navigationType == .linkActivated
        )

        let decision = policyEngine.decidePolicy(for: context)

        switch decision {
        case .allow:
            decisionHandler(.allow)
            
        case .cancel:
            decisionHandler(.cancel)
            
        case .forceTempChat:
            decisionHandler(.cancel)
            DispatchQueue.main.async { [weak self] in
                self?.loadInitialChat()
            }
            
        case .openExternalPrompt(let targetURL):
            decisionHandler(.cancel)
            if let window = webView.window {
                ExternalLinkPromptPresenter.show(url: targetURL, on: window) { shouldOpen in
                    if shouldOpen {
                        NSWorkspace.shared.open(targetURL)
                    }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }

        let context = NavigationContext(
            url: url,
            isMainFrame: true,
            navigationType: navigationAction.navigationType,
            isUserInitiated: true
        )
        
        let decision = policyEngine.decidePolicy(for: context)
        
        switch decision {
        case .openExternalPrompt(let targetURL):
            if let window = webView.window {
                ExternalLinkPromptPresenter.show(url: targetURL, on: window) { shouldOpen in
                    if shouldOpen {
                        NSWorkspace.shared.open(targetURL)
                    }
                }
            }
        case .allow, .forceTempChat:
            webView.load(URLRequest(url: url))
        default:
            break
        }
        
        return nil
    }
}

// MARK: - Helpers

private extension ChatWebViewModel {
    static let historyBlockRuleJSON = """
    [
      {
        "trigger": { "url-filter": "https://chatgpt.com/backend-api/conversations" },
        "action": { "type": "block" }
      },
      {
        "trigger": { "url-filter": "https://chatgpt.com/backend-api/conversation" },
        "action": { "type": "block" }
      }
    ]
    """
}