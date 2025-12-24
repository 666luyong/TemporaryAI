import SwiftUI
import Combine

struct TabItem: Identifiable {
    let id = UUID()
    let viewModel: ChatWebViewModel
    var title: String = "新对话"
    let aiType: AIType
}

final class TabManager: ObservableObject {
    @Published var tabs: [TabItem] = []
    @Published var activeTabId: UUID?
    
    init() {
        // Start with one tab
        addTab(aiType: .chatGPT) // Default to ChatGPT on launch
    }
    
    func addTab(aiType: AIType) {
        let newModel = ChatWebViewModel(aiType: aiType)
        var newTab = TabItem(viewModel: newModel, aiType: aiType)
        
        // Bind model title changes to TabItem title
        // This ensures the TabManager publishes changes when a tab's title updates
        newModel.onTitleChange = { [weak self] newTitle in
            guard let self = self else { return }
            if let index = self.tabs.firstIndex(where: { $0.id == newTab.id }) {
                self.tabs[index].title = newTitle
            }
        }
        
        // Initial tab title can be AI type + "新对话"
        newTab.title = aiType.rawValue + " 新对话"
        tabs.append(newTab)
        activeTabId = newTab.id
    }
    
    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        // If closing active tab, switch to another
        if activeTabId == id {
            if index > 0 {
                activeTabId = tabs[index - 1].id
            } else if index < tabs.count - 1 {
                activeTabId = tabs[index + 1].id
            } else {
                // Closing last tab
                activeTabId = nil
            }
        }
        
        tabs.remove(at: index)
        
        // If no tabs left, create a new one (Chrome behavior usually closes app, but for this app keeping one alive is safer)
        if tabs.isEmpty {
            addTab(aiType: .chatGPT) // Default to ChatGPT when last tab closed
        }
    }
    
    func activateTab(id: UUID) {
        activeTabId = id
    }
    
    var activeViewModel: ChatWebViewModel? {
        guard let id = activeTabId else { return nil }
        return tabs.first(where: { $0.id == id })?.viewModel
    }
    
    var activeTab: TabItem? {
        guard let id = activeTabId else { return nil }
        return tabs.first(where: { $0.id == id })
    }
}
