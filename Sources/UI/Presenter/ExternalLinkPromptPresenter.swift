import AppKit

final class ExternalLinkPromptPresenter {
    
    /// 在指定窗口显示外部链接确认弹窗
    /// - Parameters:
    ///   - url: 目标 URL
    ///   - window: 宿主窗口
    ///   - completion: 回调结果 (shouldOpenExternally: Bool)
    static func show(url: URL, on window: NSWindow, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "打开外部链接？"
        alert.informativeText = "此应用仅允许访问 ChatGPT。\n目标链接：\(url.absoluteString)"
        
        alert.addButton(withTitle: "使用浏览器打开") // Response 1000
        alert.addButton(withTitle: "取消")          // Response 1001
        alert.addButton(withTitle: "复制链接")      // Response 1002
        
        alert.alertStyle = .informational
        
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: // 打开
                completion(true)
            case .alertThirdButtonReturn: // 复制
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                completion(false)
            default: // 取消
                completion(false)
            }
        }
    }
}
