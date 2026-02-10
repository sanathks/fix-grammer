import AppKit
import Carbon
import Foundation
import Combine

struct Shortcut: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier flags

    var displayString: String {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("\u{2303}") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("\u{2325}") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("\u{21E7}") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("\u{2318}") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }
}

struct RewriteMode: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var prompt: String
}

final class Settings: ObservableObject {
    static let shared = Settings()

    @Published var ollamaURL: String {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: "ollamaURL") }
    }

    @Published var modelName: String {
        didSet { UserDefaults.standard.set(modelName, forKey: "modelName") }
    }

    @Published var grammarShortcut: Shortcut {
        didSet {
            UserDefaults.standard.set(grammarShortcut.keyCode, forKey: "grammarKeyCode")
            UserDefaults.standard.set(grammarShortcut.modifiers, forKey: "grammarModifiers")
        }
    }

    @Published var rewriteShortcut: Shortcut {
        didSet {
            UserDefaults.standard.set(rewriteShortcut.keyCode, forKey: "rewriteKeyCode")
            UserDefaults.standard.set(rewriteShortcut.modifiers, forKey: "rewriteModifiers")
        }
    }

    @Published var defaultModeId: UUID? {
        didSet {
            if let id = defaultModeId {
                UserDefaults.standard.set(id.uuidString, forKey: "defaultModeId")
            } else {
                UserDefaults.standard.removeObject(forKey: "defaultModeId")
            }
        }
    }

    @Published var rewriteModes: [RewriteMode] {
        didSet {
            if let data = try? JSONEncoder().encode(rewriteModes) {
                UserDefaults.standard.set(data, forKey: "rewriteModes")
            }
        }
    }

    static let defaultRewriteModes: [RewriteMode] = [
        RewriteMode(
            id: UUID(),
            name: "Clarity",
            prompt: "Rewrite the following text for maximum clarity and readability. Use simple, direct language and short sentences. Prefer active voice over passive voice. Remove filler words, redundant phrases, and unnecessary jargon. Break long sentences into shorter ones. Preserve the original meaning and all key information. Fix any grammar or spelling errors."
        ),
        RewriteMode(
            id: UUID(),
            name: "My Tone",
            prompt: "casual and friendly, like texting a close colleague"
        ),
        RewriteMode(
            id: UUID(),
            name: "Humanize",
            prompt: "Rewrite the following text to sound natural and human-written. Use contractions, vary sentence length, and prefer active voice. Remove stiff connectors like \"Moreover\" and \"Furthermore\" and let ideas flow naturally. Avoid overused AI words like \"delve\", \"game-changing\", \"unlock\", \"landscape\", or \"groundbreaking\". Keep the original meaning and do not add new information. Fix any grammar or spelling errors."
        ),
        RewriteMode(
            id: UUID(),
            name: "Professional",
            prompt: "Rewrite the following text in a professional, polished tone suitable for business communication. Be clear and confident but not stiff or overly formal. Write like a competent colleague, not a legal document. Use precise vocabulary, complete sentences, and a respectful tone. Remove slang, filler words, and casual phrasing. Preserve the original meaning and all key information. Fix any grammar or spelling errors."
        ),
    ]

    private init() {
        let defaults = UserDefaults.standard
        self.ollamaURL = defaults.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        self.modelName = defaults.string(forKey: "modelName") ?? "gemma3"

        // Default: Ctrl+Shift+G for grammar
        let gCode = defaults.object(forKey: "grammarKeyCode") as? UInt32
            ?? UInt32(kVK_ANSI_G)
        let gMods = defaults.object(forKey: "grammarModifiers") as? UInt32
            ?? UInt32(controlKey | shiftKey)
        self.grammarShortcut = Shortcut(keyCode: gCode, modifiers: gMods)

        // Default: Ctrl+Shift+T for rewrite (migrate from old toneKeyCode/toneModifiers)
        let rCode = defaults.object(forKey: "rewriteKeyCode") as? UInt32
            ?? defaults.object(forKey: "toneKeyCode") as? UInt32
            ?? UInt32(kVK_ANSI_T)
        let rMods = defaults.object(forKey: "rewriteModifiers") as? UInt32
            ?? defaults.object(forKey: "toneModifiers") as? UInt32
            ?? UInt32(controlKey | shiftKey)
        self.rewriteShortcut = Shortcut(keyCode: rCode, modifiers: rMods)

        // Load default mode
        if let idString = defaults.string(forKey: "defaultModeId"),
           let uuid = UUID(uuidString: idString) {
            self.defaultModeId = uuid
        } else {
            self.defaultModeId = nil
        }

        // Load rewrite modes from UserDefaults or use defaults
        if let data = defaults.data(forKey: "rewriteModes"),
           let modes = try? JSONDecoder().decode([RewriteMode].self, from: data) {
            self.rewriteModes = modes
        } else {
            self.rewriteModes = Settings.defaultRewriteModes
        }
    }
}

// Map virtual key codes to display strings
func keyCodeToString(_ keyCode: UInt32) -> String {
    let map: [UInt32: String] = [
        UInt32(kVK_ANSI_A): "A", UInt32(kVK_ANSI_B): "B", UInt32(kVK_ANSI_C): "C",
        UInt32(kVK_ANSI_D): "D", UInt32(kVK_ANSI_E): "E", UInt32(kVK_ANSI_F): "F",
        UInt32(kVK_ANSI_G): "G", UInt32(kVK_ANSI_H): "H", UInt32(kVK_ANSI_I): "I",
        UInt32(kVK_ANSI_J): "J", UInt32(kVK_ANSI_K): "K", UInt32(kVK_ANSI_L): "L",
        UInt32(kVK_ANSI_M): "M", UInt32(kVK_ANSI_N): "N", UInt32(kVK_ANSI_O): "O",
        UInt32(kVK_ANSI_P): "P", UInt32(kVK_ANSI_Q): "Q", UInt32(kVK_ANSI_R): "R",
        UInt32(kVK_ANSI_S): "S", UInt32(kVK_ANSI_T): "T", UInt32(kVK_ANSI_U): "U",
        UInt32(kVK_ANSI_V): "V", UInt32(kVK_ANSI_W): "W", UInt32(kVK_ANSI_X): "X",
        UInt32(kVK_ANSI_Y): "Y", UInt32(kVK_ANSI_Z): "Z",
        UInt32(kVK_ANSI_0): "0", UInt32(kVK_ANSI_1): "1", UInt32(kVK_ANSI_2): "2",
        UInt32(kVK_ANSI_3): "3", UInt32(kVK_ANSI_4): "4", UInt32(kVK_ANSI_5): "5",
        UInt32(kVK_ANSI_6): "6", UInt32(kVK_ANSI_7): "7", UInt32(kVK_ANSI_8): "8",
        UInt32(kVK_ANSI_9): "9",
        UInt32(kVK_F1): "F1", UInt32(kVK_F2): "F2", UInt32(kVK_F3): "F3",
        UInt32(kVK_F4): "F4", UInt32(kVK_F5): "F5", UInt32(kVK_F6): "F6",
        UInt32(kVK_F7): "F7", UInt32(kVK_F8): "F8", UInt32(kVK_F9): "F9",
        UInt32(kVK_F10): "F10", UInt32(kVK_F11): "F11", UInt32(kVK_F12): "F12",
        UInt32(kVK_Space): "Space", UInt32(kVK_Return): "Return",
        UInt32(kVK_Tab): "Tab", UInt32(kVK_Escape): "Esc",
        UInt32(kVK_ANSI_Minus): "-", UInt32(kVK_ANSI_Equal): "=",
        UInt32(kVK_ANSI_LeftBracket): "[", UInt32(kVK_ANSI_RightBracket): "]",
        UInt32(kVK_ANSI_Semicolon): ";", UInt32(kVK_ANSI_Quote): "'",
        UInt32(kVK_ANSI_Comma): ",", UInt32(kVK_ANSI_Period): ".",
        UInt32(kVK_ANSI_Slash): "/", UInt32(kVK_ANSI_Backslash): "\\",
    ]
    return map[keyCode] ?? "?"
}

// Convert NSEvent modifier flags to Carbon modifier flags
func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var mods: UInt32 = 0
    if flags.contains(.command) { mods |= UInt32(cmdKey) }
    if flags.contains(.option) { mods |= UInt32(optionKey) }
    if flags.contains(.control) { mods |= UInt32(controlKey) }
    if flags.contains(.shift) { mods |= UInt32(shiftKey) }
    return mods
}
