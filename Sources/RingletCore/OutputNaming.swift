import Foundation

/// Fichier de sortie à côté de la source : « IMG.jpg », puis « IMG 2.jpg », « IMG 3.jpg »… comme le Finder.
/// Un suffixe éventuel se place avant le numéro : « IMG-sans-gps.heic », « IMG-sans-gps 2.heic ».
public enum OutputNaming {
    public static func destination(for source: URL, fileExtension: String, suffix: String = "",
                                   exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let folder = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent + suffix
        var candidate = folder.appendingPathComponent("\(name).\(fileExtension)")
        var number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(name) \(number).\(fileExtension)")
            number += 1
        }
        return candidate
    }

    /// Nom caché dans le même dossier : on y écrit, puis on renomme, pour ne jamais laisser de fichier à moitié écrit.
    static func temporary(beside output: URL) -> URL {
        output.deletingLastPathComponent().appendingPathComponent(".ringlet-\(UUID().uuidString).\(output.pathExtension)")
    }

    /// Renomme le fichier temporaire en sortie ; le supprime en cas d'échec.
    static func commit(_ temporary: URL, to output: URL) throws(ConversionError) {
        do {
            try FileManager.default.moveItem(at: temporary, to: output)
        } catch {
            try? FileManager.default.removeItem(at: temporary)
            throw .writeFailed
        }
    }
}
