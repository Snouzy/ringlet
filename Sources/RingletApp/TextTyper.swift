import AppKit
import Carbon.HIToolbox

/// Tape un texte dans l'app au premier plan, comme au clavier, sans toucher au presse-papiers.
/// Demande l'Accessibilité. Un retour à la ligne devient Entrée.
@MainActor enum TextTyper {
    static var canType: Bool { AXIsProcessTrusted() }

    static func type(_ text: String, pressReturn: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            typeLine(line, source: source)
            if index < lines.count - 1 { press(kVK_Return, source: source) }
        }
        if pressReturn { press(kVK_Return, source: source) }
    }

    /// Par paquets : un évènement porte au plus une vingtaine de caractères UTF-16.
    private static func typeLine(_ line: String, source: CGEventSource?) {
        let units = Array(line.utf16)
        stride(from: 0, to: units.count, by: 20).forEach { start in
            let chunk = Array(units[start..<min(start + 20, units.count)])
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
                // Sans modificateurs : ceux du raccourci, encore enfoncés, changeraient les caractères.
                event.flags = []
                event.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private static func press(_ key: Int, source: CGEventSource?) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(key), keyDown: down) else { continue }
            event.flags = []
            event.post(tap: .cghidEventTap)
        }
    }
}
