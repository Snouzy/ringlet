import Foundation
import Observation
import RingletCore

/// Bouton de souris qui ouvre l'anneau, en plus du raccourci clavier.
enum MouseTrigger: String, CaseIterable, Identifiable {
    case none, holdRight, middle, button4, button5
    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "Aucun"
        case .holdRight: "Clic droit maintenu (dans le Finder)"
        case .middle: "Bouton central"
        case .button4: "Bouton 4 (latéral arrière)"
        case .button5: "Bouton 5 (latéral avant)"
        }
    }

    /// Numéro du bouton dans les évènements « other mouse » ; nil pour le clic droit et pour « aucun ».
    var otherButtonNumber: Int64? {
        switch self {
        case .middle: 2
        case .button4: 3
        case .button5: 4
        case .none, .holdRight: nil
        }
    }
}

/// Réglages enregistrés dans les préférences de l'utilisateur. `onChange` prévient l'app d'appliquer le changement.
@MainActor @Observable final class Preferences {
    @ObservationIgnored var onChange: () -> Void = {}
    @ObservationIgnored private let defaults: UserDefaults

    var shortcut: HotKey.Combo { didSet { save(); onChange() } }
    var mouseTrigger: MouseTrigger { didSet { save(); onChange() } }
    /// Délai avant que le clic droit maintenu ouvre l'anneau, en secondes.
    var holdDelay: Double { didSet { save(); onChange() } }
    var jpegQuality: Double { didSet { save(); onChange() } }
    var ringSize: RingSize { didSet { save(); onChange() } }
    var hasSeenWelcome: Bool { didSet { save() } }
    var terminal: AppChoice { didSet { save(); onChange() } }
    var editor: AppChoice { didSet { save(); onChange() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shortcut = defaults.data(forKey: "shortcut").flatMap { try? JSONDecoder().decode(HotKey.Combo.self, from: $0) }
            ?? .standard
        mouseTrigger = defaults.string(forKey: "mouseTrigger").flatMap(MouseTrigger.init) ?? .none
        holdDelay = defaults.object(forKey: "holdDelay") as? Double ?? 0.28
        jpegQuality = defaults.object(forKey: "jpegQuality") as? Double ?? 0.9
        ringSize = defaults.string(forKey: "ringSize").flatMap(RingSize.init) ?? .medium
        hasSeenWelcome = defaults.bool(forKey: "hasSeenWelcome")
        terminal = defaults.string(forKey: "terminal").map(AppChoice.init)
            ?? AppChoice.firstInstalled(AppChoice.terminals, fallback: "com.apple.Terminal")
        editor = defaults.string(forKey: "editor").map(AppChoice.init)
            ?? AppChoice.firstInstalled(AppChoice.editors, fallback: "com.microsoft.VSCode")
    }

    private func save() {
        defaults.set(try? JSONEncoder().encode(shortcut), forKey: "shortcut")
        defaults.set(mouseTrigger.rawValue, forKey: "mouseTrigger")
        defaults.set(holdDelay, forKey: "holdDelay")
        defaults.set(jpegQuality, forKey: "jpegQuality")
        defaults.set(ringSize.rawValue, forKey: "ringSize")
        defaults.set(hasSeenWelcome, forKey: "hasSeenWelcome")
        defaults.set(terminal.bundleID, forKey: "terminal")
        defaults.set(editor.bundleID, forKey: "editor")
    }
}
