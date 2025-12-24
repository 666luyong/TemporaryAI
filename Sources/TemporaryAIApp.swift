import SwiftUI
import AppKit

@main
struct TemporaryAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a Settings scene just to keep the App structure valid for SwiftUI,
        // but the main window is handled by the AppDelegate.
        Settings {
            EmptyView()
        }
        .commands {
            // Ensure standard editing commands (Copy, Paste, Cut, Select All) are present
            TextEditingCommands()
            TextFormattingCommands()
            
            // Standard sidebar commands if applicable
            SidebarCommands()
            
            // Add basic window commands (Minimize, Zoom)
            CommandGroup(replacing: .windowSize) {
                // SwiftUI provides standard window commands by default
            }
            
            // Ensure "New" is removed or handled if not needed, but standard App items remain
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    let tabManager = TabManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Set Activation Policy to Regular (shows in Dock, has menu bar)
        NSApp.setActivationPolicy(.regular)
        
        // 2. Setup Main Menu - REMOVED
        // We now rely on SwiftUI's declarative .commands to generate the standard macOS menu bar.
        // This fixes compatibility issues on macOS 15 where manual NSMenu construction
        // conflicted with the system's expected behavior for SwiftUI apps.
        
        // 3. Create the window manually
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.title = localizedAppTitle()
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("Main Window")
        
        // Wrap the SwiftUI content in an NSHostingView
        let contentView = ContentView()
            .environmentObject(tabManager)
            .frame(minWidth: 1100, minHeight: 720)
            
        window.contentView = NSHostingView(rootView: contentView)
        
        self.window = window
        window.makeKeyAndOrderFront(nil)
        
        // 4. Setup Settings Observers
        setupSettingsObservers()
        updateWindowLevel()
        
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func setupSettingsObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(updateWindowLevel), name: .alwaysOnTopChanged, object: nil)
    }
    
    @objc private func updateWindowLevel() {
        guard let window = self.window else { return }
        if SettingsManager.shared.alwaysOnTop {
            window.level = .floating
        } else {
            window.level = .normal
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    private func localizedAppTitle() -> String {
        if let displayName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }
        return "Temporary AI"
    }
}
