import Foundation
import UniformTypeIdentifiers

public enum ActionKind: String, Sendable, CaseIterable {
    case convertToJPEG
    case convertToPNG
}

/// Une action de l'anneau : `shortLabel` dans le secteur, `label` sous l'anneau et dans les menus.
public struct FileAction: Sendable, Equatable, Identifiable {
    public var kind: ActionKind
    public var shortLabel: String
    public var label: String
    public var id: ActionKind { kind }
}

/// Actions proposées pour une sélection : seulement celles qui valent pour tous les fichiers.
public enum ActionCatalog {
    public static func actions(for urls: [URL]) -> [FileAction] {
        guard !urls.isEmpty, urls.allSatisfy(isHEIC) else { return [] }
        return [
            FileAction(kind: .convertToJPEG, shortLabel: "JPG", label: "Convertir en JPG"),
            FileAction(kind: .convertToPNG, shortLabel: "PNG", label: "Convertir en PNG"),
        ]
    }

    static func isHEIC(_ url: URL) -> Bool {
        guard let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .heic) || type.conforms(to: .heif)
    }
}
