import Carbon.HIToolbox
import OSLog

/// Raccourci global maintenu (Carbon) : signale l'appui et le relâché, sans autorisation d'Accessibilité.
@MainActor final class HotKey {
    struct Combo: Sendable, Equatable, Codable {
        var keyCode: UInt32
        var modifiers: UInt32
        var label: String
        static let standard = Combo(keyCode: UInt32(kVK_Space), modifiers: UInt32(controlKey | optionKey), label: "⌃⌥ Space")

        /// Libellé affiché, dans la langue de l'app : `label` est enregistré tel quel et peut dater d'une autre langue.
        var title: String {
            let symbols = String(label.prefix { "⌃⌥⇧⌘".contains($0) })
            let key = label.dropFirst(symbols.count).trimmingCharacters(in: .whitespaces)
            switch Int(keyCode) {
            case kVK_Space: return "\(symbols) \(String(localized: "Space", comment: "Touche Espace"))"
            case kVK_Return: return "\(symbols) \(String(localized: "Return", comment: "Touche Entrée"))"
            default: return "\(symbols) \(key)"
            }
        }
    }

    var onPress: () -> Void = {}
    var onRelease: () -> Void = {}
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// false si le raccourci est déjà pris par une autre app.
    func register(_ combo: Combo) -> Bool {
        unregister()
        var types = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                     EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            let pressed = GetEventKind(event) == UInt32(kEventHotKeyPressed)
            Logger(subsystem: "io.snouzy.ringlet", category: "clavier").notice("Raccourci \(pressed ? "appuyé" : "relâché", privacy: .public)")
            let hotKey = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            // Carbon appelle ce gestionnaire sur le fil principal.
            MainActor.assumeIsolated { pressed ? hotKey.onPress() : hotKey.onRelease() }
            return noErr
        }, types.count, &types, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x524E_4C54), id: 1) // « RNLT »
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        return status == noErr
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }
}
