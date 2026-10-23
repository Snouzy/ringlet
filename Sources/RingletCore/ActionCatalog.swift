import Foundation
import UniformTypeIdentifiers

public enum ActionKind: String, Sendable, CaseIterable {
    case convertToJPEG
    case convertToPNG
    case removeGPS
    case videoToMP4
    case videoTo720p
    case extractAudio
    case openTerminal
    case copyPath
    // Anneau du dossier
    case goUp
    case openEditor
    case newFolder
}

/// Une action de l'anneau : `symbol` (SF Symbol) ou à défaut `shortLabel` dans le secteur, `label` sous l'anneau.
public struct FileAction: Sendable, Equatable, Identifiable {
    public var kind: ActionKind
    public var shortLabel: String
    public var symbol: String?
    public var label: String
    public var id: ActionKind { kind }

    public init(kind: ActionKind, shortLabel: String, symbol: String? = nil, label: String) {
        self.kind = kind; self.shortLabel = shortLabel; self.symbol = symbol; self.label = label
    }
}

/// Actions proposées : seulement celles qui valent pour tous les fichiers sélectionnés, conversions d'abord
/// (la première est en haut de l'anneau), puis terminal et chemin, qui valent pour tout, et « Remonter »
/// quand les fichiers sont dans une fenêtre du Finder (pas sur le bureau).
public enum ActionCatalog {
    public static func actions(for urls: [URL], terminal: String, canGoUp: Bool = false) -> [FileAction] {
        guard !urls.isEmpty else { return [] }
        let types = urls.map { UTType(filenameExtension: $0.pathExtension) }
        var actions: [FileAction] = []
        if types.allSatisfy({ $0.map(isHEIC) ?? false }) {
            actions.append(FileAction(kind: .convertToJPEG, shortLabel: "JPG", label: "Convertir en JPG"))
            actions.append(FileAction(kind: .convertToPNG, shortLabel: "PNG", label: "Convertir en PNG"))
        }
        if types.allSatisfy({ $0.map(MetadataStripper.supports) ?? false }) {
            actions.append(FileAction(kind: .removeGPS, shortLabel: "GPS", symbol: "location.slash",
                                      label: "Copie sans position GPS"))
        }
        if types.allSatisfy({ $0?.conforms(to: .movie) ?? false }) {
            if !types.contains(where: { $0?.conforms(to: .mpeg4Movie) ?? false }) {
                actions.append(FileAction(kind: .videoToMP4, shortLabel: "MP4", label: "Convertir en MP4"))
            }
            actions.append(FileAction(kind: .videoTo720p, shortLabel: "720p", label: "Réduire en 720p"))
            actions.append(FileAction(kind: .extractAudio, shortLabel: "M4A", symbol: "waveform", label: "Extraire l'audio"))
        }
        actions.append(FileAction(kind: .openTerminal, shortLabel: "Terminal", symbol: "terminal",
                                  label: "Ouvrir dans \(terminal)"))
        actions.append(FileAction(kind: .copyPath, shortLabel: "Chemin", symbol: "doc.on.clipboard",
                                  label: urls.count == 1 ? "Copier le chemin" : "Copier les chemins"))
        if canGoUp { actions.append(goUp) }
        return actions
    }

    /// Anneau du dossier (clic dans le vide, ou aucun fichier sélectionné). « Remonter » en haut, sauf sur le bureau.
    public static func folderActions(isDesktop: Bool, terminal: String, editor: String) -> [FileAction] {
        var actions: [FileAction] = []
        if !isDesktop {
            actions.append(goUp)
        }
        actions += [
            FileAction(kind: .openTerminal, shortLabel: "Terminal", symbol: "terminal", label: "Ouvrir \(terminal) ici"),
            FileAction(kind: .openEditor, shortLabel: "Éditeur", symbol: "chevron.left.forwardslash.chevron.right",
                       label: "Ouvrir dans \(editor)"),
            FileAction(kind: .newFolder, shortLabel: "Dossier", symbol: "folder.badge.plus", label: "Nouveau dossier"),
            FileAction(kind: .copyPath, shortLabel: "Chemin", symbol: "doc.on.clipboard", label: "Copier le chemin du dossier"),
        ]
        return actions
    }

    static let goUp = FileAction(kind: .goUp, shortLabel: "Haut", symbol: "arrow.up", label: "Remonter d'un niveau")

    static func isHEIC(_ type: UTType) -> Bool { type.conforms(to: .heic) || type.conforms(to: .heif) }
}

/// Dossiers à ouvrir dans le terminal : le dossier lui-même, ou celui qui contient le fichier ; chacun une fois.
public enum FolderTargets {
    public static func folders(for urls: [URL]) -> [URL] {
        var seen = Set<String>(), result: [URL] = []
        for url in urls {
            let folder = url.hasDirectoryPath ? url : url.deletingLastPathComponent()
            let path = folder.standardizedFileURL.path
            if seen.insert(path).inserted { result.append(URL(fileURLWithPath: path, isDirectory: true)) }
        }
        return result
    }
}

/// Texte copié par « Copier le chemin » : un chemin par ligne, tel quel (sans guillemets ni échappement).
public enum PathCopy {
    public static func text(for urls: [URL]) -> String { urls.map(\.path).joined(separator: "\n") }

    public static func summary(count: Int) -> String { count == 1 ? "Chemin copié" : "\(count) chemins copiés" }
}
