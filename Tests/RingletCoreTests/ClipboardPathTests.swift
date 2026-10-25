import Foundation
import Testing
@testable import RingletCore

private let home = FileManager.default.homeDirectoryForCurrentUser.path
private let existing: Set<String> = ["/tmp/rendu final.mp4", "/tmp/projet", "\(home)/Desktop/a.png", "/Apps/Notes.app",
                                     "/src/main.swift"]
private func parse(_ text: String) -> String? { ClipboardPath.url(from: text, exists: existing.contains)?.path }

@Test func readsAPlainPath() {
    #expect(parse("/tmp/rendu final.mp4") == "/tmp/rendu final.mp4")
    #expect(parse("  /tmp/projet/\n") == "/tmp/projet")
}

@Test func acceptsTheWaysAPathGetsCopied() {
    #expect(parse("'/tmp/rendu final.mp4'") == "/tmp/rendu final.mp4")
    #expect(parse("\"/tmp/rendu final.mp4\"") == "/tmp/rendu final.mp4")
    #expect(parse("/tmp/rendu\\ final.mp4") == "/tmp/rendu final.mp4")   // copié d'un terminal
    #expect(parse("file:///tmp/rendu%20final.mp4") == "/tmp/rendu final.mp4")
    #expect(parse("~/Desktop/a.png") == "\(home)/Desktop/a.png")
    #expect(parse("/src/main.swift:42") == "/src/main.swift")           // référence de code
    #expect(parse("/src/main.swift:42:7") == "/src/main.swift")
}

@Test func findsThePathInsideACommandOrASentence() {
    #expect(parse("! open ~/Desktop/a.png") == "\(home)/Desktop/a.png")
    #expect(parse("  open '/tmp/rendu final.mp4'") == "/tmp/rendu final.mp4")
    #expect(parse("ffmpeg -i /tmp/rendu final.mp4 -c copy") == "/tmp/rendu final.mp4")
    #expect(parse("cd /tmp/projet && ls") == "/tmp/projet")
    #expect(parse("Le rendu est dans /tmp/projet.") == "/tmp/projet")
    #expect(parse("voir (/src/main.swift:42)") == "/src/main.swift")
    #expect(parse("Sol : tape cette commande\n\n  ! open ~/Desktop/a.png") == "\(home)/Desktop/a.png")
    #expect(parse("https://fitdistance.io/tmp/projet") == nil)
}

@Test func takesTheFirstLineOfSeveralPaths() {
    #expect(parse("/tmp/projet\n/tmp/rendu final.mp4") == "/tmp/projet")
}

@Test func ignoresTextThatIsNotAnExistingPath() {
    #expect(parse("") == nil)
    #expect(parse("OK, oui vas-y.") == nil)
    #expect(parse("tmp/projet") == nil)            // relatif
    #expect(parse("/tmp/absent.mov") == nil)
    #expect(parse("https://fitdistance.io/") == nil)
    #expect(parse("/" + String(repeating: "a", count: 5000)) == nil)
}

@Test func revealsAFileInItsFolderAndOpensAFolder() {
    #expect(ClipboardPath.reveal(URL(fileURLWithPath: "/tmp/a.mp4"), isFolder: false, isPackage: false) == .selectInFolder)
    #expect(ClipboardPath.reveal(URL(fileURLWithPath: "/tmp/projet"), isFolder: true, isPackage: false) == .openFolder)
    // Une app ou un paquet est un dossier, mais l'« ouvrir » le lancerait : on le montre dans son dossier.
    #expect(ClipboardPath.reveal(URL(fileURLWithPath: "/Apps/Notes.app"), isFolder: true, isPackage: true) == .selectInFolder)
}

@Test func theActionNamesWhatItShows() {
    let file = ClipboardPath.action(for: URL(fileURLWithPath: "/tmp/rendu final.mp4"), opensFolder: false)
    #expect(file.kind == .revealCopiedPath)
    #expect(file.label == "Show “rendu final.mp4” in Finder")
    #expect(file.symbol != nil)
    let folder = ClipboardPath.action(for: URL(fileURLWithPath: "/tmp/projet"), opensFolder: true)
    #expect(folder.label == "Open “projet” in Finder")
}

@Test func fallsBackToTheLastCopiedPathWhileItExists() {
    let current = URL(fileURLWithPath: "/tmp/projet"), last = URL(fileURLWithPath: "/tmp/rendu final.mp4")
    #expect(ClipboardPath.choose(current: current, remembered: last, exists: existing.contains) == current)
    // Du texte copié depuis : le chemin d'avant reste proposé.
    #expect(ClipboardPath.choose(current: nil, remembered: last, exists: existing.contains) == last)
    // Supprimé ou disque débranché : plus rien.
    #expect(ClipboardPath.choose(current: nil, remembered: URL(fileURLWithPath: "/tmp/absent.mov"),
                                 exists: existing.contains) == nil)
    #expect(ClipboardPath.choose(current: nil, remembered: nil, exists: existing.contains) == nil)
}
