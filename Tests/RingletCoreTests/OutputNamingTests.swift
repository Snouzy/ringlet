import Foundation
import Testing
@testable import RingletCore

@Test func outputSitsNextToSourceWithNewExtension() {
    let source = URL(fileURLWithPath: "/Users/m/Downloads/IMG_2041.HEIC")
    #expect(OutputNaming.destination(for: source, fileExtension: "jpg", exists: { _ in false }).path
            == "/Users/m/Downloads/IMG_2041.jpg")
}

@Test func takenNamesGetANumberLikeTheFinder() {
    let source = URL(fileURLWithPath: "/d/IMG.heic")
    let taken: Set<String> = ["/d/IMG.jpg", "/d/IMG 2.jpg"]
    #expect(OutputNaming.destination(for: source, fileExtension: "jpg", exists: { taken.contains($0.path) }).path
            == "/d/IMG 3.jpg")
}

@Test func dotsInsideTheNameAreKept() {
    let source = URL(fileURLWithPath: "/d/vacances.2026.heic")
    #expect(OutputNaming.destination(for: source, fileExtension: "png", exists: { _ in false }).lastPathComponent
            == "vacances.2026.png")
}
