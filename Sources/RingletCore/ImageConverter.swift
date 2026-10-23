import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ImageFormat: Sendable, Equatable {
    case jpeg(quality: Double)
    case png

    public var type: UTType {
        switch self {
        case .jpeg: .jpeg
        case .png: .png
        }
    }

    public var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .png: "png"
        }
    }
}

public enum ConversionError: Error, Sendable, Equatable {
    /// Fichier illisible ou qui n'est pas une image.
    case unreadable
    /// L'image n'a pas pu être écrite (disque plein, dossier en lecture seule…).
    case writeFailed
    /// Vidéo sans piste audio à extraire.
    case noAudio
}

public struct ConversionResult: Sendable, Equatable {
    public var source: URL
    public var output: URL?
    public var error: ConversionError?
}

/// Conversion par ImageIO. Les pixels sont tournés selon l'orientation de la source, puis enregistrés avec
/// l'orientation 1 : le résultat s'affiche droit partout, même dans les lecteurs qui ignorent l'EXIF.
/// Le reste des métadonnées (EXIF, GPS, TIFF…) est recopié. La source n'est jamais modifiée.
public enum ImageConverter {
    public static func convert(_ source: URL, to format: ImageFormat) throws(ConversionError) -> URL {
        guard let input = CGImageSourceCreateWithURL(source as CFURL, nil), CGImageSourceGetCount(input) > 0 else {
            throw .unreadable
        }
        let index = CGImageSourceGetPrimaryImageIndex(input)
        guard let props = CGImageSourceCopyPropertiesAtIndex(input, index, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int,
              let height = props[kCGImagePropertyPixelHeight] as? Int,
              let image = CGImageSourceCreateThumbnailAtIndex(input, index, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(width, height),
              ] as CFDictionary)
        else { throw .unreadable }

        let output = OutputNaming.destination(for: source, fileExtension: format.fileExtension)
        let temporary = OutputNaming.temporary(beside: output)
        guard let destination = CGImageDestinationCreateWithURL(temporary as CFURL, format.type.identifier as CFString, 1, nil)
        else { throw .writeFailed }
        CGImageDestinationAddImage(destination, image, metadata(from: props, for: format) as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: temporary)
            throw .writeFailed
        }
        try OutputNaming.commit(temporary, to: output)
        return output
    }

    /// Convertit chaque fichier ; un échec n'arrête pas les suivants. Résultats dans l'ordre des sources.
    public static func convertAll(_ sources: [URL], to format: ImageFormat) -> [ConversionResult] {
        sources.map { source in
            do throws(ConversionError) {
                return ConversionResult(source: source, output: try convert(source, to: format), error: nil)
            } catch {
                return ConversionResult(source: source, output: nil, error: error)
            }
        }
    }

    private static func metadata(from props: [CFString: Any], for format: ImageFormat) -> [CFString: Any] {
        var result = props
        result[kCGImagePropertyOrientation] = 1
        if var tiff = result[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            result[kCGImagePropertyTIFFDictionary] = tiff
        }
        // Dimensions recalculées par ImageIO à partir des pixels tournés.
        result[kCGImagePropertyPixelWidth] = nil
        result[kCGImagePropertyPixelHeight] = nil
        if case .jpeg(let quality) = format { result[kCGImageDestinationLossyCompressionQuality] = quality }
        return result
    }
}
