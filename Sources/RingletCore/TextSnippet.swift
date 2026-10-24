import Foundation

/// Texte que l'anneau tape dans l'app au premier plan (« OK, oui vas-y. » dans un terminal, par exemple).
public struct TextSnippet: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    /// Libellé court, dans la tranche ; vide, on prend le début du texte.
    public var label: String
    public var text: String
    /// Appuie sur Entrée une fois le texte tapé (pour valider une réponse dans un terminal).
    public var pressReturn: Bool
    /// Identifiants des apps où le texte apparaît ; vide, dans toutes les apps sauf le Finder.
    public var apps: [String]

    public init(id: UUID = UUID(), label: String = "", text: String = "", pressReturn: Bool = false, apps: [String] = []) {
        self.id = id; self.label = label; self.text = text; self.pressReturn = pressReturn; self.apps = apps
    }

    /// Ce que montre la tranche : le libellé, sinon les premiers mots du texte.
    public var shortLabel: String {
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if !label.isEmpty { return label }
        return Self.truncated(text.split(whereSeparator: \.isWhitespace).prefix(2).joined(separator: " "), to: 14)
    }

    /// Ce que montre la pastille sous l'anneau : le texte sur une ligne, ⏎ s'il est validé par Entrée.
    public var caption: String {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return Self.truncated(line, to: 48) + (pressReturn ? " ⏎" : "")
    }

    static func truncated(_ text: String, to length: Int) -> String {
        text.count > length ? text.prefix(length - 1).trimmingCharacters(in: .whitespaces) + "…" : text
    }
}

/// Textes de l'anneau pour l'app au premier plan.
public enum SnippetCatalog {
    /// Au-delà, les tranches deviennent trop étroites pour un libellé.
    public static let maxPerRing = 8

    /// Ceux de l'app (ou de toutes les apps), dans l'ordre des réglages, sans les textes vides.
    public static func snippets(_ all: [TextSnippet], forApp bundleID: String?) -> [TextSnippet] {
        let matching = all.filter { snippet in
            !snippet.text.isEmpty && (snippet.apps.isEmpty || bundleID.map(snippet.apps.contains) == true)
        }
        return Array(matching.prefix(maxPerRing))
    }

    public static func actions(for snippets: [TextSnippet]) -> [FileAction] {
        snippets.map { FileAction(kind: .typeText, shortLabel: $0.shortLabel, label: $0.caption, snippet: $0) }
    }
}
