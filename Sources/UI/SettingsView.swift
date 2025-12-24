import SwiftUI
import WebKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var settings = SettingsManager.shared
    @State private var selectedTab: SettingsTab = .general
    
    // Alert state for Clear Data Confirmation (Data Clearing)
    @State private var showClearDataAlert = false
    
    // Alert state for General Messages (Data Clearing Success)
    @State private var showGeneralAlert = false
    @State private var generalAlertMessage = ""
    
    // Alert state for Cookie Operations (Export/Import/Clear success or error)
    @State private var showCookieAlert = false
    @State private var cookieAlertMessage = ""
    
    @State private var isClearingData = false

    enum SettingsTab: String, CaseIterable {
        case general = "通用"
        case privacy = "隐私"
        case scripts = "脚本"
        case advanced = "高级"

        var iconName: String {
            switch self {
            case .general: return "gearshape"
            case .privacy: return "hand.raised"
            case .scripts: return "scroll"
            case .advanced: return "hammer"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                // Sidebar
                VStack(spacing: 4) {
                    ForEach(SettingsTab.allCases, id: \.self) { tab in
                        SettingsTabButton(tab: tab, isSelected: selectedTab == tab) {
                            selectedTab = tab
                        }
                    }
                    Spacer()
                }
                .padding(.vertical)
                .padding(.horizontal, 8)
                .frame(width: 150)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                // Content
                VStack {
                    switch selectedTab {
                    case .general:
                        GeneralSettingsView(settings: settings)
                    case .privacy:
                        PrivacySettingsView(
                            settings: settings,
                            showClearDataAlert: $showClearDataAlert,
                            showCookieAlert: $showCookieAlert,
                            cookieAlertMessage: $cookieAlertMessage
                        )
                    case .scripts:
                        ScriptSettingsView(settings: settings)
                    case .advanced:
                        AdvancedSettingsView(settings: settings)
                    }
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(width: 600, height: 480)
        // 1. Clear Data Confirmation Alert
        .alert(isPresented: $showClearDataAlert) {
            Alert(
                title: Text("清除所有数据？"),
                message: Text("这将清除所有 Cookies、缓存和本地存储。您需要重新登录。此操作无法撤销。"),
                primaryButton: .destructive(Text("清除"), action: clearAllData),
                secondaryButton: .cancel()
            )
        }
        // 2. Cookie Operation Alert (Success/Fail)
        .background(
            EmptyView().alert(isPresented: $showCookieAlert) {
                Alert(title: Text("Cookie 操作"), message: Text(cookieAlertMessage), dismissButton: .default(Text("OK")))
            }
        )
        // 3. General Operation Alert (Clear Data Success)
        .background(
            EmptyView().alert(isPresented: $showGeneralAlert) {
                Alert(title: Text("提示"), message: Text(generalAlertMessage), dismissButton: .default(Text("OK")))
            }
        )
    }
    
    private func clearAllData() {
        isClearingData = true
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)
        
        dataStore.removeData(ofTypes: types, modifiedSince: date) {
            DispatchQueue.main.async {
                isClearingData = false
                generalAlertMessage = "所有数据已成功清除。"
                showGeneralAlert = true
            }
        }
    }
}

struct SettingsTabButton: View {
    let tab: SettingsView.SettingsTab
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 14))
                    .foregroundColor(isSelected ? .white : .primary)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section {
                Toggle("窗口置顶", isOn: $settings.alwaysOnTop)
                    .help("保持窗口在所有其他窗口之上")
            }
            
            Section {
                Toggle("启动时强制临时模式", isOn: .constant(true))
                    .disabled(true)
                Text("本应用设计为强制使用临时聊天模式，以保护隐私。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// Defines the context for the password sheet
enum PrivacySheetType: Identifiable {
    case expiryChoice
    case export(AIType)
    case importEncrypted(CookieExportContainer)
    
    var id: String {
        switch self {
        case .expiryChoice: return "expiry"
        case .export(let type): return "export-\(type)"
        case .importEncrypted: return "import"
        }
    }
}

struct PrivacySettingsView: View {
    @ObservedObject var settings: SettingsManager
    @Binding var showClearDataAlert: Bool
    @Binding var showCookieAlert: Bool
    @Binding var cookieAlertMessage: String
    
    // State for Sheet Management
    @State private var activeSheet: PrivacySheetType?
    
    // State for Export Flow
    @State private var showEncryptionChoice = false
    // showExpiryChoice removed as we use sheet now
    @State private var pendingExportType: AIType?
    @State private var pendingExpiryDuration: TimeInterval? = nil
    
    var body: some View {
        Form {
            Section(header: Text("界面隐私")) {
                Toggle("隐藏历史记录侧边栏", isOn: $settings.hideSidebar)
                    .help("通过 CSS 注入隐藏网页左侧的历史记录栏")
                
                if !settings.hideSidebar {
                    Text("更改将在刷新页面后生效。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Cookie 管理")) {
                Grid(alignment: .leading, horizontalSpacing: 20) {
                    GridRow {
                        Text("ChatGPT")
                        HStack {
                            Button("导出") { initiateExport(type: .chatGPT) }
                            Button("导入") { initiateImport() }
                            Button("清除") { clearCookies(type: .chatGPT) }
                        }
                    }
                    GridRow {
                        Text("Gemini")
                        HStack {
                            Button("导出") { initiateExport(type: .gemini) }
                            Button("导入") { initiateImport() }
                            Button("清除") { clearCookies(type: .gemini) }
                        }
                    }
                }
                Text("支持 AES-256 加密导出。请妥善保管您的 Cookies。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Section(header: Text("数据清理")) {
                Button("清除所有缓存与 Cookies") {
                    showClearDataAlert = true
                }
                .foregroundColor(.red)
                
                Text("这将登出您的账号并清除所有本地缓存。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        // Step 2: Encryption Choice (Step 1 is now a Sheet)
        .alert("加密选项", isPresented: $showEncryptionChoice) {
            Button("加密导出 (推荐)") {
                if let type = pendingExportType {
                    activeSheet = .export(type)
                }
            }
            Button("直接导出 (不加密)") {
                if let type = pendingExportType {
                    performExport(type: type, password: nil)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("您希望对导出的 Cookie 文件进行加密吗？加密后需凭密码导入。")
        }
        // Step 1 & 3: Sheets
        .sheet(item: $activeSheet) { item in
            switch item {
            case .expiryChoice:
                ExpiryChoiceSheet(
                    onSelect: { duration in
                        activeSheet = nil
                        handleExpirySelection(duration, proceedToEncryption: true)
                    },
                    onCancel: {
                        activeSheet = nil
                        handleExpirySelection(nil, proceedToEncryption: false)
                    }
                )
            case .export(let type):
                PasswordInputSheet(
                    isExport: true,
                    onConfirm: { password in
                        activeSheet = nil
                        performExport(type: type, password: password)
                    },
                    onCancel: { activeSheet = nil }
                )
            case .importEncrypted(let container):
                PasswordInputSheet(
                    isExport: false,
                    onConfirm: { password in
                        activeSheet = nil
                        performImport(container: container, password: password)
                    },
                    onCancel: { activeSheet = nil }
                )
            }
        }
    }
    
    // MARK: - Export Logic
    
    private func initiateExport(type: AIType) {
        pendingExportType = type
        activeSheet = .expiryChoice // Start Step 1
    }
    
    private func handleExpirySelection(_ duration: TimeInterval?, proceedToEncryption: Bool) {
        pendingExpiryDuration = duration
        if proceedToEncryption {
            // Use a small delay to allow the dialog to dismiss cleanly before showing the alert
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showEncryptionChoice = true // Start Step 2
            }
        } else {
            // Cancelled
            self.pendingExportType = nil
        }
    }
    
    private func performExport(type: AIType, password: String?) {
        let domains: [String]
        let defaultName: String
        
        switch type {
        case .chatGPT:
            domains = ["openai.com", "chatgpt.com"]
            defaultName = "chatgpt_cookies.json"
        case .gemini:
            domains = ["google.com"]
            defaultName = "gemini_cookies.json"
        }
        
        CookieManager.shared.exportCookies(for: domains, password: password, expiryDuration: pendingExpiryDuration) { result in
            switch result {
            case .success(let json):
                DispatchQueue.main.async {
                    let savePanel = NSSavePanel()
                    savePanel.allowedContentTypes = [.json]
                    savePanel.nameFieldStringValue = defaultName
                    savePanel.canCreateDirectories = true
                    savePanel.title = "保存 Cookie 文件"
                    
                    savePanel.begin { response in
                        if response == .OK, let url = savePanel.url {
                            do {
                                try json.write(to: url, atomically: true, encoding: .utf8)
                                self.cookieAlertMessage = "导出成功！"
                                self.showCookieAlert = true
                            } catch {
                                self.cookieAlertMessage = "写入失败: \(error.localizedDescription)"
                                self.showCookieAlert = true
                            }
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.cookieAlertMessage = "导出生成失败: \(error.localizedDescription)"
                    self.showCookieAlert = true
                }
            }
        }
    }
    
    // ... import logic and clear cookies logic same as before ...
    // To save context space, assuming rest is identical to previous version unless specified
    
    // MARK: - Import Logic
    
    private func initiateImport() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.title = "选择 Cookie 文件"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                do {
                    let json = try String(contentsOf: url)
                    let parseResult = CookieManager.shared.parseContainer(from: json)
                    
                    switch parseResult {
                    case .success(let container):
                        if container.isEncrypted {
                            // Need password
                            DispatchQueue.main.async {
                                self.activeSheet = .importEncrypted(container)
                            }
                        } else {
                            // Direct import
                            performImport(container: container, password: nil)
                        }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.cookieAlertMessage = "文件解析失败: \(error.localizedDescription)"
                            self.showCookieAlert = true
                        }
                    }
                } catch {
                    self.cookieAlertMessage = "读取文件失败: \(error.localizedDescription)"
                    self.showCookieAlert = true
                }
            }
        }
    }
    
    private func performImport(container: CookieExportContainer, password: String?) {
        CookieManager.shared.importCookies(from: container, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let count):
                    self.cookieAlertMessage = "成功导入 \(count) 个 Cookie！请刷新页面。"
                case .failure(let error):
                    if let cryptoError = error as? CryptoError, cryptoError == .invalidPassword {
                        self.cookieAlertMessage = "导入失败：密码错误。"
                    } else {
                        self.cookieAlertMessage = "导入失败: \(error.localizedDescription)"
                    }
                }
                self.showCookieAlert = true
            }
        }
    }
    
    private func clearCookies(type: AIType) {
        let domains: [String]
        let name: String
        switch type {
        case .chatGPT:
            domains = ["openai.com", "chatgpt.com"]
            name = "ChatGPT"
        case .gemini:
            domains = ["google.com", "gemini.google.com"]
            name = "Gemini"
        }
        CookieManager.shared.clearCookies(for: domains) {
            DispatchQueue.main.async {
                self.cookieAlertMessage = "\(name) Cookie 清除成功！"
                self.showCookieAlert = true
            }
        }
    }
}

// Simple Password Sheet
struct PasswordInputSheet: View {
    let isExport: Bool
    let onConfirm: (String) -> Void
    let onCancel: () -> Void
    
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text(isExport ? "设置导出密码" : "输入解密密码")
                .font(.headline)
            
            SecureField("密码", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 220)
            
            if isExport {
                SecureField("确认密码", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 220)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button("取消", action: onCancel)
                Button("确定") {
                    if isExport && password != confirmPassword {
                        errorMessage = "密码不一致"
                        return
                    }
                    if password.isEmpty {
                        errorMessage = "密码不能为空"
                        return
                    }
                    onConfirm(password)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ScriptSettingsView: View {
    @ObservedObject var settings: SettingsManager
    @State private var selectedScope: SettingsManager.ScriptScope = .global
    @State private var scriptContent: String = ""
    @State private var showSaveConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("脚本范围", selection: $selectedScope) {
                ForEach(SettingsManager.ScriptScope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedScope) { newValue in
                loadScript(for: newValue)
            }
            
            Toggle("启用此脚本", isOn: Binding(
                get: { settings.getScriptEnabled(for: selectedScope) },
                set: { settings.setScriptEnabled($0, for: selectedScope) }
            ))
            
            Text("在此处编辑注入的 JavaScript 代码。更改将在刷新页面后生效。")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $scriptContent)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
            HStack {
                Button("恢复默认") {
                    settings.resetScript(for: selectedScope)
                    loadScript(for: selectedScope)
                }
                Spacer()
                Button("保存") {
                    settings.setScript(scriptContent, for: selectedScope)
                    showSaveConfirmation = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showSaveConfirmation = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            
            if showSaveConfirmation {
                Text("保存成功！")
                    .font(.caption)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
        }
        //.padding() // Removed extra padding as parent already has padding
        .onAppear {
            loadScript(for: selectedScope)
        }
    }
    
    private func loadScript(for scope: SettingsManager.ScriptScope) {
        scriptContent = settings.getScript(for: scope)
    }
}

struct AdvancedSettingsView: View {
    @ObservedObject var settings: SettingsManager
    
    var body: some View {
        Form {
            Section(header: Text("User Agent")) {
                TextField("Custom User Agent", text: $settings.customUserAgent)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if settings.customUserAgent.isEmpty {
                    Text("默认: \(settings.defaultUserAgent)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Button("恢复默认") {
                        settings.customUserAgent = ""
                    }
                    .font(.caption)
                }
            }
            
            Section(header: Text("调试")) {
                Toggle("允许网页检查器 (Web Inspector)", isOn: $settings.allowWebInspector)
                    .help("开启后，右键点击网页可使用“检查元素”。需要刷新页面生效。")
                
                Toggle("显示脚本调试面板 (Debug HUD)", isOn: $settings.showDebugHUD)
                    .help("在页面右上角显示脚本运行状态，用于调试自动化逻辑。")
                
                Button("强制刷新临时聊天") {
                    NotificationCenter.default.post(name: Notification.Name("ForceReloadTempChat"), object: nil)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ExpiryChoiceSheet: View {
    let onSelect: (TimeInterval?) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("修改 Cookie 有效期")
                .font(.headline)
            Text("您可以为导出的 Cookie 设置一个新的过期时间。")
                .font(.caption)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 10) {
                Button("1 天") { onSelect(86400) }
                Button("7 天") { onSelect(86400 * 7) }
                Button("30 天") { onSelect(86400 * 30) }
                Button("90 天") { onSelect(86400 * 90) }
                Button("不修改") { onSelect(nil) }
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
            
            Button("取消") { onCancel() }
                .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 300)
    }
}