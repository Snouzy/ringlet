import AppKit
import ApplicationServices

/// État des deux autorisations de Ringlet, et les liens vers le bon panneau de Réglages Système.
enum Permissions {
    enum State { case granted, denied, notAsked, unknown }

    /// Automatisation › Finder, sans rien demander à l'utilisateur.
    static var finder: State {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
        guard let desc = target.aeDesc else { return .unknown }
        let status = AEDeterminePermissionToAutomateTarget(desc, typeWildCard, typeWildCard, false)
        switch Int(status) {
        case Int(noErr): return .granted
        case -1743: return .denied        // errAEEventNotPermitted
        case -1744: return .notAsked      // errAEEventWouldRequireUserConsent
        default: return .unknown          // Finder pas lancé, par exemple
        }
    }

    static var accessibility: State { AXIsProcessTrusted() ? .granted : .notAsked }

    /// Affiche la demande système d'Accessibilité (une seule fois par app) et ajoute Ringlet à la liste.
    static func requestAccessibility() {
        let prompt = "AXTrustedCheckOptionPrompt" as CFString
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
    }

    static func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private static func open(_ link: String) {
        if let url = URL(string: link) { NSWorkspace.shared.open(url) }
    }
}
