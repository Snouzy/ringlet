import Foundation

/// Fichier de sortie à côté de la source : « IMG.jpg », puis « IMG 2.jpg », « IMG 3.jpg »… comme le Finder.
public enum OutputNaming {
    public static func destination(for source: URL, fileExtension: String,
                                   exists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }) -> URL {
        let folder = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent
        var candidate = folder.appendingPathComponent("\(name).\(fileExtension)")
        var number = 2
        while exists(candidate) {
            candidate = folder.appendingPathComponent("\(name) \(number).\(fileExtension)")
            number += 1
        }
        return candidate
    }
}
