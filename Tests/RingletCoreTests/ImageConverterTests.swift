import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import RingletCore

/// Dossier temporaire propre à chaque test, supprimé à la fin.
private final class TempDir {
    let url: URL
    init() throws {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("ringlet-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    deinit { try? FileManager.default.removeItem(at: url) }
    var contents: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).sorted() }
}

/// HEIC de 64×32 px (moitié gauche rouge), orientation 6 (à tourner de 90° dans le sens horaire), EXIF et TIFF remplis.
private func makeHEIC(at url: URL) throws {
    let context = try #require(CGContext(data: nil, width: 64, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 64, height: 32))
    context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 32, height: 32))
    let image = try #require(context.makeImage())
    let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.heic.identifier as CFString, 1, nil))
    let props: [CFString: Any] = [
        kCGImagePropertyOrientation: 6,
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:23 12:41:49"],
        kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "Apple", kCGImagePropertyTIFFOrientation: 6],
    ]
    CGImageDestinationAddImage(dest, image, props as CFDictionary)
    #expect(CGImageDestinationFinalize(dest))
}

private func properties(of url: URL) throws -> [CFString: Any] {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
}

@Test(arguments: [ImageFormat.jpeg(quality: 0.9), .png])
func convertsHEICAppliesOrientationAndKeepsMetadata(format: ImageFormat) throws {
    let dir = try TempDir()
    let source = dir.url.appendingPathComponent("IMG_2041.HEIC")
    try makeHEIC(at: source)
    let original = try Data(contentsOf: source)

    let output = try ImageConverter.convert(source, to: format)

    #expect(output.lastPathComponent == "IMG_2041.\(format.fileExtension)")
    #expect(dir.contents == ["IMG_2041.HEIC", "IMG_2041.\(format.fileExtension)"])
    #expect(try Data(contentsOf: source) == original)
    let props = try properties(of: output)
    // Pixels déjà tournés : 32×64, et plus aucune rotation demandée aux lecteurs.
    #expect(props[kCGImagePropertyPixelWidth] as? Int == 32)
    #expect(props[kCGImagePropertyPixelHeight] as? Int == 64)
    #expect((props[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
    let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any]
    #expect(exif?[kCGImagePropertyExifDateTimeOriginal] as? String == "2026:10:23 12:41:49")
    let type = CGImageSourceGetType(try #require(CGImageSourceCreateWithURL(output as CFURL, nil))) as String?
    #expect(type == format.type.identifier)
}

@Test func secondConversionDoesNotOverwriteTheFirst() throws {
    let dir = try TempDir()
    let source = dir.url.appendingPathComponent("IMG.heic")
    try makeHEIC(at: source)
    _ = try ImageConverter.convert(source, to: .png)
    let second = try ImageConverter.convert(source, to: .png)
    #expect(second.lastPathComponent == "IMG 2.png")
    #expect(dir.contents == ["IMG 2.png", "IMG.heic", "IMG.png"])
}

@Test func unreadableFileFailsWithoutLeavingAnything() throws {
    let dir = try TempDir()
    let source = dir.url.appendingPathComponent("faux.heic")
    try Data("pas une image".utf8).write(to: source)
    #expect(throws: ConversionError.unreadable) { try ImageConverter.convert(source, to: .jpeg(quality: 0.9)) }
    #expect(dir.contents == ["faux.heic"])
}

@Test func batchKeepsGoingAfterAFailure() throws {
    let dir = try TempDir()
    let good = dir.url.appendingPathComponent("a.heic"), bad = dir.url.appendingPathComponent("b.heic")
    try makeHEIC(at: good)
    try Data("x".utf8).write(to: bad)
    let results = ImageConverter.convertAll([bad, good], to: .jpeg(quality: 0.9))
    #expect(results.count == 2)
    #expect(results[0].output == nil && results[0].error == .unreadable)
    #expect(results[1].output?.lastPathComponent == "a.jpg")
}
