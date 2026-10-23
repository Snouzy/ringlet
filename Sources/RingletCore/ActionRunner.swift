import Foundation

extension ActionKind {
    /// Format de sortie des conversions d'image ; nil pour les autres actions.
    public func format(jpegQuality: Double) -> ImageFormat? {
        switch self {
        case .convertToJPEG: .jpeg(quality: jpegQuality)
        case .convertToPNG: .png
        default: nil
        }
    }

    /// Préréglage des exports vidéo ; nil pour les autres actions.
    public var videoPreset: VideoExporter.Preset? {
        switch self {
        case .videoToMP4: .mp4
        case .videoTo720p: .hd720
        case .extractAudio: .audio
        default: nil
        }
    }

    /// Actions qui créent des fichiers (et donc un résumé « N fichiers créés »).
    public var createsFiles: Bool { format(jpegQuality: 1) != nil || videoPreset != nil || self == .removeGPS }
}

public enum ActionRunner {
    /// Exécute une action qui crée des fichiers, sur chacun, sans s'arrêter au premier échec. Vide pour les autres
    /// actions (chemin, terminal, navigation…), que l'app gère. À lancer hors du fil principal : les images bloquent.
    public static func run(_ kind: ActionKind, on urls: [URL], jpegQuality: Double = 0.9) async -> [ConversionResult] {
        if let format = kind.format(jpegQuality: jpegQuality) { return ImageConverter.convertAll(urls, to: format) }
        if let preset = kind.videoPreset { return await VideoExporter.exportAll(urls, as: preset) }
        if kind == .removeGPS { return MetadataStripper.removeGPSAll(urls) }
        return []
    }
}

/// Message court montré après une action : « IMG.jpg créé », « 3 fichiers créés, 1 échec », « IMG.heic est illisible ».
public struct ResultSummary: Sendable, Equatable {
    public var text: String
    public var hasFailures: Bool

    public init(results: [ConversionResult]) {
        let created = results.compactMap(\.output)
        let failed = results.filter { $0.output == nil }
        hasFailures = !failed.isEmpty
        switch (created.count, failed.count) {
        case (1, 0):
            text = "\(created[0].lastPathComponent) créé"
        case (let ok, 0):
            text = "\(ok) fichiers créés"
        case (0, 1):
            let name = failed[0].source.lastPathComponent
            switch failed[0].error {
            case .writeFailed: text = "Impossible d'écrire à côté de \(name)"
            case .noAudio: text = "\(name) n'a pas de son"
            default: text = "\(name) est illisible"
            }
        case (0, let ko):
            text = "\(ko) échecs"
        case (let ok, let ko):
            text = "\(ok == 1 ? "1 fichier créé" : "\(ok) fichiers créés"), \(ko == 1 ? "1 échec" : "\(ko) échecs")"
        }
    }
}
