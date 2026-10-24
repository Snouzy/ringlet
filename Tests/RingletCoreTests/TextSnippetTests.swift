import Foundation
import Testing
@testable import RingletCore

private let ghostty = "com.mitchellh.ghostty"

@Test func snippetsFollowTheFrontApp() {
    let yes = TextSnippet(label: "OK go", text: "OK, oui vas-y.", pressReturn: true, apps: [ghostty])
    let everywhere = TextSnippet(text: "Merci !")
    let cursor = TextSnippet(text: "Relis le diff", apps: ["com.todesktop.230313mzl4w4u92"])
    let all = [yes, everywhere, cursor]
    #expect(SnippetCatalog.snippets(all, forApp: ghostty) == [yes, everywhere])
    #expect(SnippetCatalog.snippets(all, forApp: "com.apple.Safari") == [everywhere])
    #expect(SnippetCatalog.snippets(all, forApp: nil) == [everywhere])
}

@Test func emptyTextsStayOutAndTheRingKeepsEight() {
    let many = (1...10).map { TextSnippet(text: "Texte \($0)") } + [TextSnippet(label: "Vide")]
    let shown = SnippetCatalog.snippets(many, forApp: ghostty)
    #expect(shown.count == SnippetCatalog.maxPerRing)
    #expect(shown.first?.text == "Texte 1")
}

@Test func sliceShowsTheLabelOrTheFirstWords() {
    #expect(TextSnippet(label: " OK go ", text: "OK, oui vas-y.").shortLabel == "OK go")
    #expect(TextSnippet(text: "OK, oui vas-y.").shortLabel == "OK, oui")
    #expect(TextSnippet(text: "Anticonstitutionnellement oui").shortLabel == "Anticonstitut…")
}

@Test func captionIsOneLineAndMarksReturn() {
    #expect(TextSnippet(text: "OK, oui vas-y.", pressReturn: true).caption == "OK, oui vas-y. ⏎")
    #expect(TextSnippet(text: "ligne 1\nligne 2").caption == "ligne 1 ligne 2")
    let long = TextSnippet(text: String(repeating: "mot ", count: 20)).caption
    #expect(long.count == 48 && long.hasSuffix("…"))
}

@Test func eachSnippetIsItsOwnSlice() {
    let a = TextSnippet(text: "Oui"), b = TextSnippet(text: "Non")
    let actions = SnippetCatalog.actions(for: [a, b])
    #expect(actions.map(\.kind) == [.typeText, .typeText])
    #expect(Set(actions.map(\.id)).count == 2)
    #expect(actions.map(\.snippet) == [a, b])
}

@Test func snippetsSurviveSaving() throws {
    let snippet = TextSnippet(label: "OK go", text: "OK, oui vas-y.", pressReturn: true, apps: [ghostty])
    let data = try JSONEncoder().encode([snippet])
    #expect(try JSONDecoder().decode([TextSnippet].self, from: data) == [snippet])
}
