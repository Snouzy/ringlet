import Foundation
import UniformTypeIdentifiers

public enum ActionKind: String, Sendable, CaseIterable {
    case quickLook
    case convertToJPEG
    case convertToPNG
    case removeGPS
    case videoToMP4
    case videoTo720p
    case extractAudio
    case openTerminal
    case copyPath
    case revealCopiedPath
    // Anneau du dossier
    case goUp
    case goDown
    case openEditor
    case newFolder
    // Anneau des textes (apps autres que le Finder)
    case typeText
    case paste
}

/// Une action de l'anneau : `symbol` (SF Symbol) ou à défaut `shortLabel` dans le secteur, `label` sous l'anneau.
/// `snippet` : le texte à taper, pour `typeText`.
public struct FileAction: Sendable, Equatable, Identifiable {
    public var kind: ActionKind
    public var shortLabel: String
    public var symbol: String?
    public var label: String
    public var snippet: TextSnippet?
    public var id: String { snippet.map { $0.id.uuidString } ?? kind.rawValue }

    public init(kind: ActionKind, shortLabel: String, symbol: String? = nil, label: String, snippet: TextSnippet? = nil) {
        self.kind = kind; self.shortLabel = shortLabel; self.symbol = symbol; self.label = label; self.snippet = snippet
    }
}

/// Actions proposées : « Remonter » quand les fichiers sont dans une fenêtre du Finder (pas sur le bureau),
/// l'aperçu, celles qui valent pour tous les fichiers sélectionnés (conversions), puis terminal, éditeur et chemin,
/// qui valent pour tout. Leur place dans l'anneau vient de `RingHours`, pas de cet ordre.
public enum ActionCatalog {
    public static func actions(for urls: [URL], terminal: String, editor: String, canGoUp: Bool = false) -> [FileAction] {
        guard !urls.isEmpty else { return [] }
        let types = urls.map { UTType(filenameExtension: $0.pathExtension) }
        var actions = canGoUp ? [goUp] : []
        actions.append(quickLook)
        if types.allSatisfy({ $0.map(isHEIC) ?? false }) {
            actions += [convertToJPEG, convertToPNG]
        }
        if types.allSatisfy({ $0.map(MetadataStripper.supports) ?? false }) {
            actions.append(removeGPS)
        }
        if types.allSatisfy({ $0?.conforms(to: .movie) ?? false }) {
            if !types.contains(where: { $0?.conforms(to: .mpeg4Movie) ?? false }) {
                actions.append(videoToMP4)
            }
            actions += [videoTo720p, extractAudio]
        }
        actions += [
            openTerminal(label: String(localized: "Open in \(terminal)")),
            openEditor(editor),
            copyPath(label: urls.count == 1 ? String(localized: "Copy path") : String(localized: "Copy paths")),
        ]
        return actions
    }

    /// Anneau du dossier (clic dans le vide, ou aucun fichier sélectionné). « Remonter », sauf sur le bureau.
    public static func folderActions(isDesktop: Bool, terminal: String, editor: String) -> [FileAction] {
        var actions: [FileAction] = []
        if !isDesktop {
            actions.append(goUp)
        }
        actions += [
            openTerminal(label: String(localized: "Open \(terminal) here")),
            openEditor(editor),
            newFolder,
            copyPath(label: String(localized: "Copy folder path")),
        ]
        return actions
    }

    /// Toutes les actions des anneaux du Finder, une par sorte, pour choisir leur heure dans les réglages.
    public static func everyFileAction(terminal: String, editor: String) -> [FileAction] {
        [goUp, quickLook, convertToJPEG, convertToPNG, removeGPS, videoToMP4, videoTo720p, extractAudio,
         openTerminal(label: String(localized: "Open in \(terminal)")), openEditor(editor), newFolder,
         copyPath(label: String(localized: "Copy path")), revealCopiedPath, goDown]
    }

    static let goUp = FileAction(kind: .goUp, shortLabel: String(localized: "Up"), symbol: "arrow.up",
                                 label: String(localized: "Go up one level"))
    static let quickLook = FileAction(kind: .quickLook, shortLabel: String(localized: "Preview"), symbol: "eye", label: String(localized: "Preview"))
    static let convertToJPEG = FileAction(kind: .convertToJPEG, shortLabel: "JPG", label: String(localized: "Convert to JPG"))
    static let convertToPNG = FileAction(kind: .convertToPNG, shortLabel: "PNG", label: String(localized: "Convert to PNG"))
    static let removeGPS = FileAction(kind: .removeGPS, shortLabel: "GPS", symbol: "location.slash",
                                      label: String(localized: "Copy without GPS location"))
    static let videoToMP4 = FileAction(kind: .videoToMP4, shortLabel: "MP4", label: String(localized: "Convert to MP4"))
    static let videoTo720p = FileAction(kind: .videoTo720p, shortLabel: "720p", label: String(localized: "Shrink to 720p"))
    static let extractAudio = FileAction(kind: .extractAudio, shortLabel: "M4A", symbol: "waveform", label: String(localized: "Extract audio"))
    static let newFolder = FileAction(kind: .newFolder, shortLabel: String(localized: "Folder"), symbol: "folder.badge.plus",
                                      label: String(localized: "New folder"))
    /// Les deux actions dont le libellé nomme l'élément visé, ici sans lui (pour le cadran des réglages).
    public static let revealCopiedPath = FileAction(kind: .revealCopiedPath, shortLabel: String(localized: "Copied"),
                                             symbol: "arrow.right.doc.on.clipboard", label: String(localized: "Show the copied path in Finder"))
    static let goDown = FileAction(kind: .goDown, shortLabel: String(localized: "Down"), symbol: "arrow.down",
                                   label: String(localized: "Back down"))

    static func openTerminal(label: String) -> FileAction {
        FileAction(kind: .openTerminal, shortLabel: String(localized: "Terminal"), symbol: "terminal", label: label)
    }
    static func openEditor(_ editor: String) -> FileAction {
        FileAction(kind: .openEditor, shortLabel: String(localized: "Editor"), symbol: "chevron.left.forwardslash.chevron.right",
                   label: String(localized: "Open in \(editor)"))
    }
    static func copyPath(label: String) -> FileAction {
        FileAction(kind: .copyPath, shortLabel: String(localized: "Path"), symbol: "doc.on.clipboard", label: label)
    }

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

    /// Dossier où sont rangés les éléments choisis, celui qu'affiche la fenêtre du Finder (le premier s'ils sont
    /// dans plusieurs). Pour un dossier choisi, c'est son parent, pas le dossier lui-même.
    public static func containing(_ urls: [URL]) -> URL? {
        urls.first.map { URL(fileURLWithPath: $0.standardizedFileURL.deletingLastPathComponent().path, isDirectory: true) }
    }
}

/// Texte copié par « Copier le chemin » : un chemin par ligne, tel quel (sans guillemets ni échappement).
public enum PathCopy {
    public static func text(for urls: [URL]) -> String { urls.map(\.path).joined(separator: "\n") }

    public static func summary(count: Int) -> String { count == 1 ? String(localized: "Path copied") : String(localized: "\(count) paths copied") }
}
