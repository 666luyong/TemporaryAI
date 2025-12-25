<p align="center">
  <img src="Resources/icon_1024.png" width="128" height="128" alt="App Icon">
</p>

# 临时AI (Private ChatGPT & Gemini)

[English Documentation](README.md)

一个基于 SwiftUI + WKWebView 的 macOS 原生应用，专为 **隐私优先** 的 AI 聊天体验设计。它强制开启 AI 服务的“临时聊天”模式，并主动隐藏历史记录访问，确保你的对话“阅后即焚”。

<p align="center">
  <img src="screenshot/screenshot.png" alt="Screenshot" width="50%">
</p>


[用户交流](screenshot/wechat_group.jpg)
## 核心特性

- **隐私优先 (Privacy First)**：
    - 强制使用 `https://chatgpt.com/?temporary-chat=true` 和 Gemini 的临时模式。
    - 自动拦截历史记录页面（`/c/*`）、分享链接和非白名单域名。
    - **无痕浏览**：支持配置为非持久化存储（类似浏览器的隐身模式）。
- **多 Tab 管理**：
    - 支持同时打开多个 ChatGPT 或 Gemini 标签页，独立管理。
    - 侧边栏式 Tab 切换，更符合桌面应用习惯。
- **纯净界面**：
    - 注入 JavaScript/CSS 自动隐藏原网页的侧边栏、历史记录列表和干扰元素。
    - 提供原生 macOS 顶部工具栏：刷新、主页、强制新对话。
- **安全导航引擎**：
    - 内置 `NavigationPolicyEngine`，严格控制页面跳转。
    - 点击外部链接（如搜索引用）时，会弹出原生 macOS 确认框，防止意外跳出。

## 📥 获取与安装

### 方式一：自行构建 (推荐)

本项目是一个标准的 Swift Package Manager (SPM) 项目。

**要求：**
- macOS 13.0+
- Xcode 15+ (或安装了 Swift 5.9+ 工具链)

**步骤：**
1. 克隆本项目：
   ```bash
   git clone https://github.com/yourusername/Private-ChatGPT.git
   cd Private-ChatGPT
   ```
2. 使用内置脚本打包（自动处理图标和目录结构）：
   ```bash
   chmod +x build_app.sh
   ./build_app.sh
   ```
3. 构建完成后，`build/` 目录下会生成 `临时AI.app`，直接拖入“应用程序”文件夹即可。

### 方式二：Xcode 调试
1. 双击 `Package.swift` 或在终端运行 `xed .` 打开项目。
2. 顶部 Scheme 选择 `TemporaryAI`。
3. 配置 Signing & Capabilities (选择你的 Team)。
4. 点击 Run (Cmd + R)。

## ⚙️ 配置与自定义脚本

为了遵守开源合规性并允许用户自定义，本项目**默认不包含**用于隐藏网页侧边栏并强制进入临时会话模式的专有 JavaScript 脚本。
未来将会以合适的形式发布适配当前 ChatGPT 或 Gemini 官方页面的脚本。

### 如何启用界面优化脚本？

在 `Sources/Resources/` 目录下，你会看到以下示例文件：
- `chatgpt_default_script.js.example`
- `gemini_default_script.js.example`

默认情况下应用**不会加载任何优化脚本**，网页行为保持原样，只有在你提供代码后才会生效。

**启用方法：**

1. **直接重命名（推荐开发使用）**：
   将上述文件重命名为 `chatgpt_default_script.js` 和 `gemini_default_script.js`，并在其中编写你的 DOM 操作代码（例如 `document.querySelector('...').style.display = 'none'`）。

2. **在 App 设置中配置（推荐用户使用）**：
   启动 App 后，点击右上角齿轮图标进入 **设置 (Settings)** -> **脚本 (Scripts)**。
   - 你可以在这里直接粘贴 JavaScript 代码。
   - 设置中的脚本优先级高于本地文件。

## 🛠 技术架构

- **UI 框架**：SwiftUI (AppKit Lifecycle)
- **Web 内核**：WKWebView + UserScripts (JS注入)
- **架构模式**：MVVM
- **关键模块**：
    - `NavigationPolicyEngine`: 负责决策每一次 URL 跳转是 Allow, Block 还是 Redirect。
    - `UserScriptManager`: 管理 CSS/JS 注入。
    - `TabManager`: 管理多标签页状态。


## 📄 开源协议

本项目基于 [MIT License](LICENSE) 开源。
您可以免费使用、修改和分发本项目，具体请参阅 LICENSE 文件。
