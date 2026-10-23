import Foundation
import Testing
@testable import RingletCore

private func urls(_ names: String...) -> [URL] { names.map { URL(fileURLWithPath: "/tmp/\($0)") } }
private func kinds(_ names: String...) -> [ActionKind] {
    ActionCatalog.actions(for: names.map { URL(fileURLWithPath: "/tmp/\($0)") }, terminal: "Ghostty").map(\.kind)
}

@Test func heicOffersConversionsThenGPSThenTerminalAndPath() {
    #expect(kinds("IMG_1.HEIC", "IMG_2.heic", "photo.heif")
            == [.convertToJPEG, .convertToPNG, .removeGPS, .openTerminal, .copyPath])
}

@Test func otherImagesOnlyOfferGPSRemoval() {
    #expect(kinds("logo.png", "photo.jpg") == [.removeGPS, .openTerminal, .copyPath])
    #expect(kinds("IMG_1.HEIC", "photo.jpeg") == [.removeGPS, .openTerminal, .copyPath])
}

@Test func videosOfferMP4OnlyWhenNoneIsMP4Already() {
    #expect(kinds("clip.mov", "demo.MOV") == [.videoToMP4, .videoTo720p, .extractAudio, .openTerminal, .copyPath])
    #expect(kinds("clip.mov", "demo.mp4") == [.videoTo720p, .extractAudio, .openTerminal, .copyPath])
    // Un .m4v est déjà du MPEG-4.
    #expect(kinds("demo.m4v") == [.videoTo720p, .extractAudio, .openTerminal, .copyPath])
}

@Test func anythingElseGetsTerminalAndPath() {
    #expect(kinds("facture.pdf") == [.openTerminal, .copyPath])
    #expect(kinds("IMG_1.HEIC", "clip.mov") == [.openTerminal, .copyPath])
    #expect(kinds("sans-extension") == [.openTerminal, .copyPath])
    #expect(ActionCatalog.actions(for: [], terminal: "Ghostty").isEmpty)
}

@Test func filesCanGoUpLast() {
    let actions = ActionCatalog.actions(for: [URL(fileURLWithPath: "/tmp/IMG.heic")], terminal: "T", canGoUp: true)
    #expect(actions.map(\.kind) == [.convertToJPEG, .convertToPNG, .removeGPS, .openTerminal, .copyPath, .goUp])
}

@Test func labelsNameTheChosenApps() {
    let file = ActionCatalog.actions(for: urls("a.pdf", "b.pdf"), terminal: "Ghostty")
    #expect(file.map(\.label) == ["Ouvrir dans Ghostty", "Copier les chemins"])
    let folder = ActionCatalog.folderActions(isDesktop: false, terminal: "Ghostty", editor: "Visual Studio Code")
    #expect(folder.map(\.kind) == [.goUp, .openTerminal, .openEditor, .newFolder, .copyPath])
    #expect(folder.map(\.label) == ["Remonter d'un niveau", "Ouvrir Ghostty ici", "Ouvrir dans Visual Studio Code",
                                    "Nouveau dossier", "Copier le chemin du dossier"])
}

@Test func desktopHasNowhereToGoUp() {
    #expect(ActionCatalog.folderActions(isDesktop: true, terminal: "T", editor: "E").map(\.kind)
            == [.openTerminal, .openEditor, .newFolder, .copyPath])
}

@Test func everyActionHasASymbolOrAShortLabel() {
    let all = ActionCatalog.actions(for: urls("a.heic"), terminal: "T")
        + ActionCatalog.actions(for: urls("a.mov"), terminal: "T")
        + ActionCatalog.folderActions(isDesktop: false, terminal: "T", editor: "E")
    #expect(all.allSatisfy { $0.symbol != nil || !$0.shortLabel.isEmpty })
}

@Test func terminalOpensEachDistinctFolderOnce() {
    let picked = [URL(fileURLWithPath: "/d/a.pdf"), URL(fileURLWithPath: "/d/b.pdf"),
                  URL(fileURLWithPath: "/e/sub", isDirectory: true)]
    #expect(FolderTargets.folders(for: picked).map(\.path) == ["/d", "/e/sub"])
}

@Test func pathCopyPutsOnePathPerLine() {
    #expect(PathCopy.text(for: urls("a b.heic", "c.pdf")) == "/tmp/a b.heic\n/tmp/c.pdf")
    #expect(PathCopy.summary(count: 1) == "Chemin copié")
    #expect(PathCopy.summary(count: 3) == "3 chemins copiés")
}
