import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var tabManager: TabManager
    @State private var showBlockedInfo = false
    @State private var isSettingsPresented = false
    @State private var showingAITypeSelection = false // New state for AI type dialog

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) { // Reduced spacing for tighter browser look
                // Header (now a separate View)
                header
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                toolbar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                tabBar
                    .padding(.horizontal, 16)
                
                mainPanel
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsView()
        }
        .confirmationDialog("选择 AI 类型", isPresented: $showingAITypeSelection) {
            Button("ChatGPT") {
                tabManager.addTab(aiType: .chatGPT)
            }
            Button("Gemini") {
                tabManager.addTab(aiType: .gemini)
            }
        } message: {
            Text("您想开始与哪种 AI 的新对话？")
        }
    }

    // MARK: - Subviews

    // Changed to a computed property that returns a View
    private var header: some View {
        Group {
            if let activeTab = tabManager.activeTab {
                HeaderView(
                    title: "TemporaryAI", // Keep app title static
                    subtitle: activeTab.title, // This title is now synced via TabManager
                    url: activeTab.viewModel.currentURL
                )
            } else {
                // Fallback if no tab is active (shouldn't happen often)
                HStack {
                    Text("TemporaryAI")
                        .font(.headline)
                    Spacer()
                }
            }
        }
    }

    private var toolbar: some View {
        HStack {
            Spacer()

            HStack(spacing: 6) {
                ToolbarButton(systemName: "house", helpText: "回到首页", action: { tabManager.activeViewModel?.goHome() })
                ToolbarButton(systemName: "arrow.clockwise", helpText: "刷新页面", action: { tabManager.activeViewModel?.reload() })
                ToolbarButton(systemName: "plus", helpText: "新对话", action: { showingAITypeSelection = true }) // Trigger dialog
                ToolbarButton(systemName: "gearshape", helpText: "设置", action: { isSettingsPresented = true })
            }
        }
    }
    
    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(tabManager.tabs) { tab in
                    TabItemView(
                        title: tab.title, // Use TabItem's title
                        isActive: tabManager.activeTabId == tab.id,
                        onClose: {
                            tabManager.closeTab(id: tab.id)
                        }
                    )
                    .onTapGesture {
                        tabManager.activateTab(id: tab.id)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 32)
        .padding(.bottom, -10) // Overlap with main panel slightly for "connected" look
        .zIndex(1)
    }

    private var mainPanel: some View {
        ZStack {
            // Background for the panel
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
                .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 6)
            
            // Render ALL tabs to keep state, but hide inactive ones
            ForEach(tabManager.tabs) { tab in
                TabContentView(viewModel: tab.viewModel, isActive: tabManager.activeTabId == tab.id)
            }
        }
        .padding(.top, 8)
        .onAppear {
            // Workaround: Force a redraw shortly after launch to ensure the initial WKWebView renders correctly.
            // Sometimes NSViewControllerRepresentable inside ZStack+Opacity needs a kick.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                let current = tabManager.activeTabId
                // Briefly toggle to trigger layout update
                tabManager.activeTabId = nil 
                DispatchQueue.main.async {
                    tabManager.activeTabId = current
                }
            }
        }
    }
}

// MARK: - Sub Components

private struct HeaderView: View {
    let title: String
    let subtitle: String
    let url: String
    
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(nsColor: .systemTeal), Color(nsColor: .systemBlue)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 46, height: 46)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !url.isEmpty {
                    Text(url)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(url, forType: .string)
                        }
                }
            }

            Spacer()
        }
    }
}

private struct TabContentView: View {
    @ObservedObject var viewModel: ChatWebViewModel
    let isActive: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.blockedNavigation != nil && isActive {
                BannerView(
                    title: "已阻止离开临时聊天模式",
                    message: "此应用仅允许临时聊天。",
                    primaryTitle: "了解原因",
                    secondaryTitle: "回到临时聊天",
                    onPrimary: { /* Show info */ },
                    onSecondary: { viewModel.goHome() },
                    onClose: { viewModel.dismissBanner() }
                )
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }

            ZStack {
                // CRITICAL FIX: Do NOT set opacity to 0. WebKit pauses if hidden.
                // The Placeholder sits on top (z-index), so we don't need to hide the webview.
                ChatWebView(model: viewModel)
                    // .opacity(viewModel.showingPlaceholder ? 0 : 1) // REMOVED to fix deadlock

                if viewModel.showingPlaceholder {
                    PlaceholderView(title: viewModel.placeholderTitle, subtitle: viewModel.placeholderSubtitle)
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(isActive && viewModel.blockedNavigation != nil ? 0 : 0) // Adjust if banner shown
        }
        .opacity(isActive ? 1 : 0)
        .allowsHitTesting(isActive)
    }
}

private struct TabItemView: View {
    let title: String
    let isActive: Bool
    let onClose: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(isActive ? .medium : .regular)
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: 150)
            
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(isActive ? .secondary : Color(nsColor: .tertiaryLabelColor))
            }
            .buttonStyle(.plain)
            .padding(4)
            .background(Color.black.opacity(0.05))
            .clipShape(Circle())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isActive ? Color(nsColor: .textBackgroundColor) : Color(nsColor: .windowBackgroundColor).opacity(0.5))
                .shadow(color: Color.black.opacity(isActive ? 0.05 : 0), radius: 2, x: 0, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
    }
}

private struct ToolbarButton: View {
    let systemName: String
    let helpText: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
        }
        .buttonStyle(.plain)
        .help(helpText)
    }
}

private struct PlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [Color(nsColor: .systemTeal), Color(nsColor: .systemBlue)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 72, height: 72)
                .overlay(
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 8)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundColor(.primary)

            Text(subtitle)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}
