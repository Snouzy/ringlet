import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Bouton qui enregistre le prochain raccourci tapé (au moins ⌃, ⌥ ou ⌘). Échap annule.
struct ShortcutRecorder: View {
    @Binding var combo: HotKey.Combo
    var onRecording: (Bool) -> Void = { _ in }
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? String(localized: "Type the shortcut…") : combo.title) { isRecording ? stop() : start() }
            .frame(minWidth: 150)
            .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        onRecording(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            if let recorded = Self.combo(from: event) { combo = recorded; stop() }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if isRecording { onRecording(false) }
        isRecording = false
    }

    static func combo(from event: NSEvent) -> HotKey.Combo? {
        let flags = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !flags.intersection([.control, .option, .command]).isEmpty else { return nil }
        var carbon = 0, symbols = ""
        if flags.contains(.control) { carbon |= controlKey; symbols += "⌃" }
        if flags.contains(.option) { carbon |= optionKey; symbols += "⌥" }
        if flags.contains(.shift) { carbon |= shiftKey; symbols += "⇧" }
        if flags.contains(.command) { carbon |= cmdKey; symbols += "⌘" }
        return HotKey.Combo(keyCode: UInt32(event.keyCode), modifiers: UInt32(carbon),
                            label: "\(symbols) \(keyName(event))")
    }

    private static func keyName(_ event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "Return"
        case kVK_Tab: "Tab"
        case kVK_Delete: "⌫"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        default: (event.charactersIgnoringModifiers ?? "?").uppercased()
        }
    }
}
