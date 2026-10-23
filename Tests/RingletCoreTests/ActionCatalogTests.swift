import Foundation
import Testing
@testable import RingletCore

private func urls(_ names: String...) -> [URL] { names.map { URL(fileURLWithPath: "/tmp/\($0)") } }

@Test func heicSelectionOffersJPEGThenPNG() {
    #expect(ActionCatalog.actions(for: urls("IMG_1.HEIC", "IMG_2.heic", "photo.heif")).map(\.kind)
            == [.convertToJPEG, .convertToPNG])
}

@Test func mixedOrUnsupportedSelectionOffersNothing() {
    #expect(ActionCatalog.actions(for: urls("IMG_1.HEIC", "facture.pdf")).isEmpty)
    #expect(ActionCatalog.actions(for: urls("logo.png")).isEmpty)
    #expect(ActionCatalog.actions(for: urls("sans-extension")).isEmpty)
    #expect(ActionCatalog.actions(for: []).isEmpty)
}

@Test func actionsCarryRingAndMenuLabels() {
    let jpeg = ActionCatalog.actions(for: urls("a.heic"))[0]
    #expect(jpeg.shortLabel == "JPG")
    #expect(jpeg.label == "Convertir en JPG")
}
