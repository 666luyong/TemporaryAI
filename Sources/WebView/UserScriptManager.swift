import WebKit
import Foundation

struct UserScriptManager {
    
    static func hideSidebarScript(for aiType: AIType) -> WKUserScript {
        var source = "window.__ENABLE_DEBUG_HUD = \(SettingsManager.shared.showDebugHUD);\n"
        
        switch aiType {
        case .chatGPT:
            if SettingsManager.shared.getScriptEnabled(for: .chatGPT) {
                source += SettingsManager.shared.getScript(for: .chatGPT)
            }
        case .gemini:
            if SettingsManager.shared.getScriptEnabled(for: .gemini) {
                source += SettingsManager.shared.getScript(for: .gemini)
            }
        }
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
    
    static func globalScript() -> WKUserScript? {
        guard SettingsManager.shared.getScriptEnabled(for: .global) else { return nil }
        
        let source = SettingsManager.shared.getScript(for: .global)
        guard !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}
