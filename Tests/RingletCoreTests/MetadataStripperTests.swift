import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import RingletCore

private func makeImage(at url: URL, type: UTType) throws {
    let context = try #require(CGContext(data: nil, width: 40, height: 30, bitsPerComponent: 8, bytesPerRow: 0,
                                         space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                         bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
    context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.3, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
    let dest = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
    let props: [CFString: Any] = [
        kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: "2026:10:23 21:26:21"],
        kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 47.75, kCGImagePropertyGPSLatitudeRef: "N",
                                        kCGImagePropertyGPSLongitude: 7.35, kCGImagePropertyGPSLongitudeRef: "E"],
    ]
    CGImageDestinationAddImage(dest, try #require(context.makeImage()), props as CFDictionary)
    #expect(CGImageDestinationFinalize(dest))
}

private func props(_ url: URL) throws -> [CFString: Any] {
    let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
    return try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
}

@Test(arguments: [("IMG.heic", UTType.heic), ("photo.jpg", .jpeg)])
func copyWithoutGPSKeepsTheRest(name: String, type: UTType) throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ringlet-gps-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent(name)
    try makeImage(at: source, type: type)
    #expect(try props(source)[kCGImagePropertyGPSDictionary] != nil)
    let original = try Data(contentsOf: source)

    let output = try MetadataStripper.removeGPS(from: source)

    let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
    #expect(output.lastPathComponent == "\(base)-sans-gps.\(ext)")
    let result = try props(output)
    #expect(result[kCGImagePropertyGPSDictionary] == nil)
    #expect((result[kCGImagePropertyExifDictionary] as? [CFString: Any])?[kCGImagePropertyExifDateTimeOriginal] as? String
            == "2026:10:23 21:26:21")
    #expect(result[kCGImagePropertyPixelWidth] as? Int == 40)
    #expect(try Data(contentsOf: source) == original)
    let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasPrefix(".ringlet") }
    #expect(leftovers.isEmpty)
}

@Test func removingGPSFromANonImageFails() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ringlet-gps-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let source = dir.appendingPathComponent("faux.jpg")
    try Data("x".utf8).write(to: source)
    #expect(throws: ConversionError.unreadable) { try MetadataStripper.removeGPS(from: source) }
}
