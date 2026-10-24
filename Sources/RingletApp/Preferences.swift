import Foundation
import Observation
import RingletCore

/// Bouton de souris qui ouvre l'anneau n'importe où, maintenu comme le raccourci : relâcher sur une tranche la lance.
enum MouseButton: String, CaseIterable, Identifiable {
    case none, middle, button4, button5
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .middle: String(localized: "Middle button")
        case .button4: String(localized: "Button 4 (side, back)")
        case .button5: String(localized: "Button 5 (side, forward)")
        }
    }

    /// Numéro du bouton dans les évènements « other mouse » ; nil pour « aucun ».
    var number: Int64? {
        switch self {
        case .middle: 2
        case .button4: 3
        case .button5: 4
        case .none: nil
        }
    }
}

/// Déclencheurs à la souris, cumulables : le clic droit maintenu dans le Finder, et un bouton partout.
struct MouseTriggers: Equatable {
    var holdRight = false
    var button = MouseButton.none
    var isEmpty: Bool { !holdRight && button == .none }
}

/// Réglages enregistrés dans les préférences de l'utilisateur. `onChange` prévient l'app d'appliquer le changement.
@MainActor @Observable final class Preferences {
    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored private let defaults: UserDefaults

    /// Raccourci clavier à maintenir ; aucun par défaut, on le choisit dans Déclencheurs.
    var shortcut: HotKey.Combo? { didSet { save(); onChange() } }
    /// Clic droit maintenu dans le Finder.
    var holdRightInFinder: Bool { didSet { save(); onChange() } }
    var mouseButton: MouseButton { didSet { save(); onChange() } }
    /// Délai avant que le clic droit maintenu ouvre l'anneau, en secondes.
    var holdDelay: Double { didSet { save(); onChange() } }
    var jpegQuality: Double { didSet { save(); onChange() } }
    var ringSize: RingSize { didSet { save(); onChange() } }
    var ringStyle: RingStyle { didSet { save(); onChange() } }
    var accent: RingAccent { didSet { save(); onChange() } }
    /// Opacité du verre (style Verre), de 0,3 à 0,95.
    var glassOpacity: Double { didSet { save(); onChange() } }
    /// En plus du réglage d'accessibilité de macOS.
    var reduceMotion: Bool { didSet { save(); onChange() } }
    var hasSeenWelcome: Bool { didSet { save() } }
    var terminal: AppChoice { didSet { save(); onChange() } }
    var editor: AppChoice { didSet { save(); onChange() } }
    /// Textes de l'anneau hors du Finder.
    var snippets: [TextSnippet] { didSet { save(); onChange() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(HotKey.Combo.self, from: $0) }
        // L'ancien défaut ⌃⌥ Espace était enregistré sans avoir été choisi : on l'efface une fois.
        if !defaults.bool(forKey: "formerDefaultShortcutCleared") {
            defaults.set(true, forKey: "formerDefaultShortcutCleared")
            shortcut = stored.flatMap { $0.sameKeys(as: .formerDefault) ? nil : $0 }
        } else {
            shortcut = stored
        }
        // Jusqu'à la 0.1, un seul déclencheur souris : « mouseTrigger » (none, holdRight, middle, button4, button5).
        let former = defaults.string(forKey: "mouseTrigger")
        holdRightInFinder = defaults.object(forKey: "holdRightInFinder") as? Bool ?? (former == "holdRight")
        mouseButton = defaults.string(forKey: "mouseButton").flatMap(MouseButton.init)
            ?? former.flatMap(MouseButton.init) ?? .none
        holdDelay = defaults.object(forKey: "holdDelay") as? Double ?? 0.28
        jpegQuality = defaults.object(forKey: "jpegQuality") as? Double ?? 0.9
        ringSize = defaults.string(forKey: "ringSize").flatMap(RingSize.init) ?? .medium
        ringStyle = defaults.string(forKey: "ringStyle").flatMap(RingStyle.init) ?? .glass
        accent = defaults.string(forKey: "accent").flatMap(RingAccent.init) ?? .system
        glassOpacity = GlassOpacity.clamped(defaults.object(forKey: "glassOpacity") as? Double ?? GlassOpacity.standard)
        reduceMotion = defaults.bool(forKey: "reduceMotion")
        hasSeenWelcome = defaults.bool(forKey: "hasSeenWelcome")
        terminal = defaults.string(forKey: "terminal").map(AppChoice.init)
            ?? AppChoice.firstInstalled(AppChoice.terminals, fallback: "com.apple.Terminal")
        editor = defaults.string(forKey: "editor").map(AppChoice.init)
            ?? AppChoice.firstInstalled(AppChoice.editors, fallback: "com.microsoft.VSCode")
        snippets = defaults.data(forKey: "snippets").flatMap { try? JSONDecoder().decode([TextSnippet].self, from: $0) } ?? []
    }

    private func save() {
        if let shortcut { defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut") } else { defaults.removeObject(forKey: "shortcut") }
        defaults.set(holdRightInFinder, forKey: "holdRightInFinder")
        defaults.set(mouseButton.rawValue, forKey: "mouseButton")
        defaults.removeObject(forKey: "mouseTrigger")
        defaults.set(holdDelay, forKey: "holdDelay")
        defaults.set(jpegQuality, forKey: "jpegQuality")
        defaults.set(ringSize.rawValue, forKey: "ringSize")
        defaults.set(ringStyle.rawValue, forKey: "ringStyle")
        defaults.set(accent.rawValue, forKey: "accent")
        defaults.set(glassOpacity, forKey: "glassOpacity")
        defaults.set(reduceMotion, forKey: "reduceMotion")
        defaults.set(hasSeenWelcome, forKey: "hasSeenWelcome")
        defaults.set(terminal.bundleID, forKey: "terminal")
        defaults.set(editor.bundleID, forKey: "editor")
        defaults.set(try? JSONEncoder().encode(snippets), forKey: "snippets")
    }
}

extension Preferences {
    var mouseTriggers: MouseTriggers { MouseTriggers(holdRight: holdRightInFinder, button: mouseButton) }

    var look: RingLook {
        RingLook(style: ringStyle, accent: accent, glassOpacity: glassOpacity, reduceMotion: reduceMotion)
    }
}
