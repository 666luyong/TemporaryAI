import SwiftUI
import Combine
import Foundation

final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // Lazily load bundled default scripts (if present locally)
    private lazy var bundledScriptChatGPT: String? = Self.loadBundledScript(named: "chatgpt_default_script")
    private lazy var bundledScriptGemini: String? = Self.loadBundledScript(named: "gemini_default_script")
    
    @AppStorage("alwaysOnTop") var alwaysOnTop: Bool = false {
        didSet {
            NotificationCenter.default.post(name: .alwaysOnTopChanged, object: nil)
        }
    }
    
    @AppStorage("hideSidebar") var hideSidebar: Bool = true
    
    @AppStorage("customUserAgent") var customUserAgent: String = ""
    
    @AppStorage("allowWebInspector") var allowWebInspector: Bool = false

    @AppStorage("showDebugHUD") var showDebugHUD: Bool = false
    
    // MARK: - User Scripts
    @AppStorage("isScriptEnabledGlobal") var isScriptEnabledGlobal: Bool = true
    @AppStorage("isScriptEnabledChatGPT") var isScriptEnabledChatGPT: Bool = true
    @AppStorage("isScriptEnabledGemini") var isScriptEnabledGemini: Bool = true

    @AppStorage("scriptGlobal") var scriptGlobal: String = ""
    @AppStorage("scriptChatGPT") var scriptChatGPT: String = ""
    @AppStorage("scriptGemini") var scriptGemini: String = ""
    
    // Default UA for macOS to ensure we get the desktop site
    let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    enum ScriptScope: String, CaseIterable, Identifiable {
        case global = "全局"
        case chatGPT = "ChatGPT"
        case gemini = "Gemini"
        
        var id: String { rawValue }
    }
    
    func getScriptEnabled(for scope: ScriptScope) -> Bool {
        switch scope {
        case .global: return isScriptEnabledGlobal
        case .chatGPT: return isScriptEnabledChatGPT
        case .gemini: return isScriptEnabledGemini
        }
    }

    func setScriptEnabled(_ enabled: Bool, for scope: ScriptScope) {
        switch scope {
        case .global: isScriptEnabledGlobal = enabled
        case .chatGPT: isScriptEnabledChatGPT = enabled
        case .gemini: isScriptEnabledGemini = enabled
        }
    }

    func getScript(for scope: ScriptScope) -> String {
        switch scope {
        case .global:
            return scriptGlobal
        case .chatGPT:
            let stored = scriptChatGPT.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stored.isEmpty { return scriptChatGPT }
            return bundledScriptChatGPT ?? ""
        case .gemini:
            let stored = scriptGemini.trimmingCharacters(in: .whitespacesAndNewlines)
            if !stored.isEmpty { return scriptGemini }
            return bundledScriptGemini ?? ""
        }
    }
    
    func setScript(_ content: String, for scope: ScriptScope) {
        switch scope {
        case .global: scriptGlobal = content
        case .chatGPT: scriptChatGPT = content
        case .gemini: scriptGemini = content
        }
    }
    
    func resetScript(for scope: ScriptScope) {
        switch scope {
        case .global: scriptGlobal = ""
        case .chatGPT: scriptChatGPT = ""
        case .gemini: scriptGemini = ""
        }
    }
    
    private static func loadBundledScript(named baseName: String) -> String? {
        var bundles: [Bundle] = []
        if let bundleURL = Bundle.main.url(forResource: "TemporaryAI_TemporaryAI", withExtension: "bundle"),
           let resourceBundle = Bundle(url: bundleURL) {
            bundles.append(resourceBundle)
        }
        bundles.append(Bundle.main)

        for bundle in bundles {
            if let url = bundle.url(forResource: baseName, withExtension: "js", subdirectory: "Resources")
                ?? bundle.url(forResource: baseName, withExtension: "js") {
                return try? String(contentsOf: url)
            }
        }
        return nil
    }
    
}

extension Notification.Name {
    static let alwaysOnTopChanged = Notification.Name("alwaysOnTopChanged")
}
