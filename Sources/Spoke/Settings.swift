import Foundation
import Security

enum Provider: String, CaseIterable, Identifiable {
    case groq, openai
    var id: String { rawValue }
    var label: String {
        switch self {
        case .groq: return "Groq Whisper (free tier)"
        case .openai: return "OpenAI"
        }
    }
}

enum TriggerKind: String, CaseIterable, Identifiable {
    case mouseButton, rightOption, rightCommand, fn
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mouseButton: return "Mouse button"
        case .rightOption: return "Right Option key"
        case .rightCommand: return "Right Command key"
        case .fn: return "Fn (Globe) key"
        }
    }
}

enum TriggerMode: String, CaseIterable, Identifiable {
    case toggle, hold
    var id: String { rawValue }
    var label: String {
        switch self {
        case .toggle: return "Press to start, press again to finish"
        case .hold: return "Hold while talking, release to finish"
        }
    }
}

/// User settings. API keys live in the Keychain; everything else in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    @Published var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: "provider") }
    }
    @Published var cleanupEnabled: Bool {
        didSet { defaults.set(cleanupEnabled, forKey: "cleanupEnabled") }
    }
    /// Names and jargon, one per line or comma-separated.
    @Published var vocabulary: String {
        didSet { defaults.set(vocabulary, forKey: "vocabulary") }
    }
    @Published var triggerKind: TriggerKind {
        didSet { defaults.set(triggerKind.rawValue, forKey: "triggerKind") }
    }
    /// CGEvent mouse button number: 2 = middle, 3 = back, 4 = forward, and so on.
    @Published var mouseButton: Int {
        didSet { defaults.set(mouseButton, forKey: "mouseButton") }
    }
    @Published var triggerMode: TriggerMode {
        didSet { defaults.set(triggerMode.rawValue, forKey: "triggerMode") }
    }
    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: "playSounds") }
    }

    @Published var groqKey: String { didSet { Keychain.set(groqKey, for: "groq") } }
    @Published var openaiKey: String { didSet { Keychain.set(openaiKey, for: "openai") } }
    @Published var anthropicKey: String { didSet { Keychain.set(anthropicKey, for: "anthropic") } }

    private init() {
        provider = Provider(rawValue: defaults.string(forKey: "provider") ?? "") ?? .groq
        cleanupEnabled = defaults.object(forKey: "cleanupEnabled") as? Bool ?? true
        vocabulary = defaults.string(forKey: "vocabulary") ?? ""
        triggerKind = TriggerKind(rawValue: defaults.string(forKey: "triggerKind") ?? "") ?? .mouseButton
        mouseButton = defaults.object(forKey: "mouseButton") as? Int ?? 3
        triggerMode = TriggerMode(rawValue: defaults.string(forKey: "triggerMode") ?? "") ?? .toggle
        playSounds = defaults.object(forKey: "playSounds") as? Bool ?? true
        groqKey = Keychain.get("groq")
        openaiKey = Keychain.get("openai")
        anthropicKey = Keychain.get("anthropic")
    }

    var transcriptionKey: String {
        switch provider {
        case .groq: return groqKey
        case .openai: return openaiKey
        }
    }

    var vocabularyTerms: [String] {
        vocabulary
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func mouseButtonName(_ number: Int) -> String {
        switch number {
        case 2: return "Middle button"
        case 3: return "Back side button"
        case 4: return "Forward side button"
        default: return "Button \(number + 1)"
        }
    }
}

/// Minimal Keychain wrapper for the API keys.
enum Keychain {
    private static let service = "com.gstout.spoke"

    static func get(_ account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func set(_ value: String, for account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !trimmed.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
}
