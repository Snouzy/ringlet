import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Copie d'une photo sans sa position GPS, sans réencoder les pixels : l'image est recopiée telle quelle par ImageIO,
/// avec ses métadonnées d'origine moins les balises GPS (l'option « exclure le GPS » d'ImageIO ne les retire pas
/// du HEIC, et efface l'EXIF du JPEG).
public enum MetadataStripper {
    /// Formats dont ImageIO sait recopier l'image en remplaçant ses métadonnées.
    public static func supports(_ type: UTType) -> Bool {
        [UTType.heic, .heif, .jpeg, .png, .tiff].contains { type.conforms(to: $0) }
    }

    public static func removeGPS(from source: URL) throws(ConversionError) -> URL {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(input) > 0,
              let type = CGImageSourceGetType(input) else { throw .unreadable }
        let index = CGImageSourceGetPrimaryImageIndex(input)
        let original = CGImageSourceCopyMetadataAtIndex(input, index, nil)
        let metadata = original.flatMap(CGImageMetadataCreateMutableCopy) ?? CGImageMetadataCreateMutable()
        for path in gpsTagPaths(in: metadata) { CGImageMetadataRemoveTagWithPath(metadata, nil, path as CFString) }

        let output = OutputNaming.destination(for: source, fileExtension: source.pathExtension, suffix: String(localized: "-no-gps", comment: "Suffixe du nom de la copie sans GPS"))
        let temporary = OutputNaming.temporary(beside: output)
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, type, 1, nil) else { throw .writeFailed }
        let options: [CFString: Any] = [kCGImageDestinationMetadata: metadata, kCGImageDestinationMergeMetadata: false]
        guard CGImageDestinationCopyImageSource(destination, input, options as CFDictionary, nil) else {
            try? FileManager.default.removeItem(at: temporary)
            throw .writeFailed
        }
        try OutputNaming.commit(temporary, to: output)
        return output
    }

    /// Chemins (« exif:GPSLatitude »…) des balises GPS de premier niveau.
    private static func gpsTagPaths(in metadata: CGImageMetadata) -> [String] {
        var paths: [String] = []
        CGImageMetadataEnumerateTagsUsingBlock(metadata, nil, nil) { path, tag in
            let name = CGImageMetadataTagCopyName(tag) as String? ?? ""
            let prefix = CGImageMetadataTagCopyPrefix(tag) as String? ?? ""
            if name.hasPrefix("GPS") || prefix == "exifGPS" { paths.append(path as String) }
            return true
        }
        return paths
    }

    public static func removeGPSAll(_ sources: [URL]) -> [ConversionResult] {
        sources.map { source in
            do throws(ConversionError) {
                return ConversionResult(source: source, output: try removeGPS(from: source), error: nil)
            } catch {
                return ConversionResult(source: source, output: nil, error: error)
            }
        }
    }
}
