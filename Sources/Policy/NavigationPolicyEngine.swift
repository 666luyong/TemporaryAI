import Foundation
import WebKit

enum NavigationDecision: Equatable {
    case allow                 // 允许加载
    case cancel                // 默默取消
    case forceTempChat         // 强制重定向回临时聊天（用于非法跳转或退出临时模式）
    case openExternalPrompt(URL) // 弹出提示框，询问是否外部打开
}

struct NavigationContext {
    let url: URL
    let isMainFrame: Bool
    let navigationType: WKNavigationType
    let isUserInitiated: Bool // 粗略判断，通常基于 navigationType == .linkActivated
}

final class NavigationPolicyEngine {
    
    private let aiType: AIType
    private let temporaryChatURL = URL(string: "https://chatgpt.com/?temporary-chat=true")!
    private let geminiURL = URL(string: "https://gemini.google.com/app")!
    
    // 白名单主域
    private let allowedHosts: Set<String> = [
        "chatgpt.com",
        "openai.com",
        "oaistatic.com", // OpenAI 静态资源
        "oaiusercontent.com", // 用户上传内容/图片
        "gemini.google.com" // Gemini
    ]
    
    // 登录相关白名单
    private let loginHosts: Set<String> = [
        "auth.openai.com",
        "login.live.com",       // Microsoft
        "accounts.google.com",  // Google
        "appleid.apple.com",    // Apple
        "cdn.auth0.com"         // Auth0 (OpenAI 早期使用，现主要自建，但保留以防万一)
    ]
    
    // 允许的 Scheme
    private let allowedSchemes: Set<String> = ["http", "https"]

    init(aiType: AIType) {
        self.aiType = aiType
    }

    func decidePolicy(for context: NavigationContext) -> NavigationDecision {
        guard let scheme = context.url.scheme, allowedSchemes.contains(scheme) else {
            // 可以在此扩展对 mailto: 等的支持，目前默认拦截非 http/s
            return .cancel
        }
        
        // 1. 非主框架（IFrame, 资源加载）：通常允许，否则页面会挂
        if !context.isMainFrame {
            return .allow
        }
        
        guard let host = context.url.host else { return .cancel }
        
        // 2. 检查是否在允许的主机列表内
        if isAllowedHost(host) {
            // 2.1 特殊逻辑：如果是 ChatGPT 主站，必须确保是临时聊天模式
            if aiType == .chatGPT && host.hasSuffix("chatgpt.com") {
                // 如果是登录流程或 OAuth 回调，允许
                if context.url.path.hasPrefix("/auth/") || context.url.path.hasPrefix("/api/") {
                    return .allow
                }
                
                // 检查是否试图离开临时聊天（检测 history url 或普通主页）
                if isLeavingTempChat(context.url) {
                    return .forceTempChat
                }
            } else if aiType == .gemini && host.hasSuffix("gemini.google.com") {
                // For Gemini, we are less restrictive for now, just allow within its domain.
                return .allow
            }
            return .allow
        }
        
        // 3. 第三方链接处理
        // 如果是用户点击触发的 -> 弹窗询问
        if context.isUserInitiated {
            return .openExternalPrompt(context.url)
        }
        
        // 4. 非用户触发的第三方跳转（如广告重定向、自动跳转） -> 拦截并强制回初始页面
        // 避免用户莫名其妙被带离
        return .forceTempChat
    }
    
    // MARK: - Helper Logic
    
    public func isExternalDomain(_ url: URL) -> Bool {
        guard let host = url.host else { return false }
        return !isAllowedHost(host)
    }

    private func isAllowedHost(_ host: String) -> Bool {
        // 精确匹配或后缀匹配（处理子域名）
        for allowed in allowedHosts.union(loginHosts) {
            if host == allowed || host.hasSuffix("." + allowed) {
                return true
            }
        }
        return false
    }
    
    private func isLeavingTempChat(_ url: URL) -> Bool {
        // 如果是 library 页面
        if url.path.hasPrefix("/library") {
            return true
        }
        
        // 如果是 history 对话链接
        if url.path.hasPrefix("/c/") || url.path.hasPrefix("/share/") {
            return true
        }
        
        // 如果是主页，但缺少临时聊天参数
        if url.path == "/" || url.path.isEmpty {
            let query = url.query ?? ""
            if !query.contains("temporary-chat=true") {
                return true
            }
        }
        
        return false
    }
}
