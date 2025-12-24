import Foundation

enum AIType: String, CaseIterable, Identifiable {
    case chatGPT = "ChatGPT"
    case gemini = "Gemini"
    
    var id: String { rawValue }
    
    var url: URL {
        switch self {
        case .chatGPT:
            return URL(string: "https://chatgpt.com/?temporary-chat=true")!
        case .gemini:
            return URL(string: "https://gemini.google.com/app")!
        }
    }
}
