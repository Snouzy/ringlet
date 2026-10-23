import Foundation
import Testing
@testable import RingletCore

private func urls(_ names: String...) -> [URL] { names.map { URL(fileURLWithPath: "/tmp/\($0)") } }
private func kinds(_ names: String...) -> [ActionKind] {
    ActionCatalog.actions(for: names.map { URL(fileURLWithPath: "/tmp/\($0)") }, terminal: "Ghostty", editor: "VS Code").map(\.kind)
}

@Test func heicOffersConversionsThenGPSThenTerminalAndPath() {
    #expect(kinds("IMG_1.HEIC", "IMG_2.heic", "photo.heif")
            == [.quickLook, .convertToJPEG, .convertToPNG, .removeGPS, .openTerminal, .openEditor, .copyPath])
}

@Test func otherImagesOnlyOfferGPSRemoval() {
    #expect(kinds("logo.png", "photo.jpg") == [.quickLook, .removeGPS, .openTerminal, .openEditor, .copyPath])
    #expect(kinds("IMG_1.HEIC", "photo.jpeg") == [.quickLook, .removeGPS, .openTerminal, .openEditor, .copyPath])
}

@Test func videosOfferMP4OnlyWhenNoneIsMP4Already() {
    #expect(kinds("clip.mov", "demo.MOV") == [.quickLook, .videoToMP4, .videoTo720p, .extractAudio, .openTerminal, .openEditor, .copyPath])
    #expect(kinds("clip.mov", "demo.mp4") == [.quickLook, .videoTo720p, .extractAudio, .openTerminal, .openEditor, .copyPath])
    // Un .m4v est déjà du MPEG-4.
    #expect(kinds("demo.m4v") == [.quickLook, .videoTo720p, .extractAudio, .openTerminal, .openEditor, .copyPath])
}

@Test func anythingElseGetsTerminalAndPath() {
    #expect(kinds("facture.pdf") == [.quickLook, .openTerminal, .openEditor, .copyPath])
    #expect(kinds("IMG_1.HEIC", "clip.mov") == [.quickLook, .openTerminal, .openEditor, .copyPath])
    #expect(kinds("sans-extension") == [.quickLook, .openTerminal, .openEditor, .copyPath])
    #expect(ActionCatalog.actions(for: [], terminal: "Ghostty", editor: "VS Code").isEmpty)
}

@Test func filesCanGoUpLast() {
    let actions = ActionCatalog.actions(for: [URL(fileURLWithPath: "/tmp/IMG.heic")], terminal: "T", editor: "E", canGoUp: true)
    #expect(actions.map(\.kind) == [.quickLook, .convertToJPEG, .convertToPNG, .removeGPS, .openTerminal, .openEditor, .copyPath, .goUp])
}

@Test func labelsNameTheChosenApps() {
    let file = ActionCatalog.actions(for: urls("a.pdf", "b.pdf"), terminal: "Ghostty", editor: "VS Code")
    #expect(file.map(\.label) == ["Preview", "Open in Ghostty", "Open in VS Code", "Copy paths"])
    let folder = ActionCatalog.folderActions(isDesktop: false, terminal: "Ghostty", editor: "Visual Studio Code")
    #expect(folder.map(\.kind) == [.goUp, .openTerminal, .openEditor, .newFolder, .copyPath])
    #expect(folder.map(\.label) == ["Go up one level", "Open Ghostty here", "Open in Visual Studio Code",
                                    "New folder", "Copy folder path"])
}

@Test func desktopHasNowhereToGoUp() {
    #expect(ActionCatalog.folderActions(isDesktop: true, terminal: "T", editor: "E").map(\.kind)
            == [.openTerminal, .openEditor, .newFolder, .copyPath])
}

@Test func everyActionHasASymbolOrAShortLabel() {
    let all = ActionCatalog.actions(for: urls("a.heic"), terminal: "T", editor: "E")
        + ActionCatalog.actions(for: urls("a.mov"), terminal: "T", editor: "E")
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
    #expect(PathCopy.summary(count: 1) == "Path copied")
    #expect(PathCopy.summary(count: 3) == "3 paths copied")
}

@Test func goingUpStartsFromTheFolderShownInTheWindow() {
    #expect(FolderTargets.containing([URL(fileURLWithPath: "/a/b/photo.heic")])?.path == "/a/b")
    // Un dossier choisi dans la liste : la fenêtre montre son parent, d'où l'on remonte.
    #expect(FolderTargets.containing([URL(fileURLWithPath: "/a/b/projet", isDirectory: true)])?.path == "/a/b")
    #expect(FolderTargets.containing([]) == nil)
}
