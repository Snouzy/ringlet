import Foundation

/// « Afficher le chemin copié » : un chemin lu dans le presse-papiers, montré dans le Finder sans jamais ouvrir
/// le fichier (ni l'aperçu, ni l'app qui le lit).
public enum ClipboardPath {
    /// Ce que fait le Finder : ouvrir le dossier, ou ouvrir celui qui contient l'élément et le sélectionner.
    public enum Reveal: Equatable, Sendable {
        case openFolder
        case selectInFolder
    }

    /// Le chemin d'un texte copié, s'il existe. Première ligne seulement ; guillemets, `file://`, `~`, espaces
    /// échappés (`\ `, copiés d'un terminal) et numéro de ligne final (`main.swift:42`) acceptés.
    public static func url(from text: String,
                           exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL? {
        guard var line = text.split(whereSeparator: \.isNewline)
            .lazy.map({ $0.trimmingCharacters(in: .whitespaces) }).first(where: { !$0.isEmpty }),
            line.count <= 4096 else { return nil }
        for quote in ["'", "\""] where line.count > 1 && line.hasPrefix(quote) && line.hasSuffix(quote) {
            line = String(line.dropFirst().dropLast())
        }
        if line.hasPrefix("file://") {
            guard let path = URL(string: line)?.path, !path.isEmpty else { return nil }
            line = path
        }
        guard line.hasPrefix("/") || line == "~" || line.hasPrefix("~/") else { return nil }

        let unescaped = line.replacingOccurrences(of: #"\\(.)"#, with: "$1", options: .regularExpression)
        let withoutLine = unescaped.replacingOccurrences(of: #":\d+(:\d+)?$"#, with: "", options: .regularExpression)
        for candidate in [line, unescaped, withoutLine] {
            let path = (candidate as NSString).standardizingPath
            if exists(path) { return URL(fileURLWithPath: path) }
        }
        return nil
    }

    /// Le chemin du presse-papiers, sinon le dernier copié tant qu'il existe encore.
    public static func choose(current: URL?, remembered: URL?,
                              exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL? {
        current ?? remembered.flatMap { exists($0.path) ? $0 : nil }
    }

    /// Un dossier s'ouvre ; un fichier, une app ou un paquet (dossier que l'« ouvrir » lancerait) se montre sélectionné.
    public static func reveal(_ url: URL, isFolder: Bool, isPackage: Bool) -> Reveal {
        isFolder && !isPackage ? .openFolder : .selectInFolder
    }

    public static func action(for url: URL, opensFolder: Bool) -> FileAction {
        let name = url.lastPathComponent
        return FileAction(kind: .revealCopiedPath, shortLabel: String(localized: "Copied"),
                          symbol: "arrow.right.doc.on.clipboard",
                          label: opensFolder ? String(localized: "Open “\(name)” in Finder")
                                             : String(localized: "Show “\(name)” in Finder"))
    }
}
