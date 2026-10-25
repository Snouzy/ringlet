import Foundation

/// « Afficher le chemin copié » : un chemin lu dans le presse-papiers, montré dans le Finder sans jamais ouvrir
/// le fichier (ni l'aperçu, ni l'app qui le lit).
public enum ClipboardPath {
    /// Ce que fait le Finder : ouvrir le dossier, ou ouvrir celui qui contient l'élément et le sélectionner.
    public enum Reveal: Equatable, Sendable {
        case openFolder
        case selectInFolder
    }

    /// Le premier chemin existant d'un texte copié : seul (`/a/b.mp4`) ou dans une commande, une phrase
    /// (`! open ~/a/b.html`, `cd /a && ls`, `voir /a/b.mp4.`). Guillemets, `file://`, `~`, espaces échappés
    /// (`\ `, copiés d'un terminal) et numéro de ligne final (`main.swift:42`) acceptés.
    public static func url(from text: String,
                           exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> URL? {
        guard text.utf16.count <= 20_000 else { return nil }
        var budget = 300   // vérifications sur le disque, au plus
        for line in text.split(whereSeparator: \.isNewline).prefix(50) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard line.count <= 4096 else { continue }
            for start in starts(in: line) {
                // Le plus long d'abord : un chemin peut contenir des espaces ; puis coupé à chaque espace.
                var piece = line[start...]
                while true {
                    if let url = resolve(String(piece), exists: exists, budget: &budget) { return url }
                    guard budget > 0, let cut = piece.lastIndex(where: \.isWhitespace) else { break }
                    piece = piece[..<cut]
                }
                if budget <= 0 { return nil }
            }
        }
        return nil
    }

    /// Où un chemin peut commencer : `/`, `~/` ou `file://`, en début de ligne ou après un espace,
    /// un guillemet, `(`, `=`… (pas au milieu d'une URL `https://` ni d'un mot comme « et/ou »).
    static func starts(in line: String) -> [String.Index] {
        var result: [String.Index] = []
        var previous: Character?
        for index in line.indices {
            let char = line[index]
            let boundary = previous.map { $0.isWhitespace || "'\"(=[<`".contains($0) } ?? true
            if boundary {
                let rest = line[index...]
                if char == "/" || rest.hasPrefix("~/") || rest.hasPrefix("file://") { result.append(index) }
            }
            previous = char
        }
        return result
    }

    private static func resolve(_ raw: String, exists: (String) -> Bool, budget: inout Int) -> URL? {
        let trailing = CharacterSet(charactersIn: "'\"`),;.:]>")
        var forms = [raw]
        let trimmed = String(raw.unicodeScalars.reversed().drop(while: trailing.contains).reversed().map(Character.init))
        if trimmed != raw { forms.append(trimmed) }
        for form in forms {
            var line = form
            for quote in ["'", "\""] where line.count > 1 && line.hasPrefix(quote) && line.hasSuffix(quote) {
                line = String(line.dropFirst().dropLast())
            }
            if line.hasPrefix("file://") {
                guard let path = URL(string: line)?.path, !path.isEmpty else { continue }
                line = path
            }
            guard line.hasPrefix("/") || line.hasPrefix("~/") else { continue }
            let unescaped = line.replacingOccurrences(of: #"\\(.)"#, with: "$1", options: .regularExpression)
            let withoutLine = unescaped.replacingOccurrences(of: #":\d+(:\d+)?$"#, with: "", options: .regularExpression)
            for candidate in [line, unescaped, withoutLine] {
                budget -= 1
                guard budget >= 0 else { return nil }
                let path = (candidate as NSString).standardizingPath
                if path != "/", exists(path) { return URL(fileURLWithPath: path) }
            }
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
