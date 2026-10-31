import Testing
@testable import RingletCore

private func action(_ kind: ActionKind) -> FileAction { FileAction(kind: kind, shortLabel: kind.rawValue, label: kind.rawValue) }
private func text(_ label: String) -> FileAction {
    let snippet = TextSnippet(label: label, text: label)
    return FileAction(kind: .typeText, shortLabel: label, label: label, snippet: snippet)
}

@Test func everyActionSitsAtItsHourSortedClockwise() {
    let placed = RingHours.place([action(.copyPath), action(.goUp), action(.openTerminal)], hours: RingHours.fileDefaults)
    #expect(placed.map(\.action.kind) == [.goUp, .copyPath, .openTerminal])
    #expect(placed.map(\.hour) == [0, 5, 9])
    #expect(RingHours.angle(of: 0) == -90)
    #expect(RingHours.angle(of: 6) == 90)   // « Redescendre » en bas, en face de « Remonter »
    #expect(RingHours.fileDefaults[ActionKind.goDown.rawValue] == 6)
}

@Test func twoActionsOnTheSameHourTheSecondTakesTheNextFreeOne() {
    // JPG et MP4 partagent 2 h : ils ne se présentent jamais ensemble.
    let placed = RingHours.place([action(.convertToJPEG), action(.videoToMP4), action(.convertToPNG)],
                                 hours: [ActionKind.convertToJPEG.rawValue: 2, ActionKind.videoToMP4.rawValue: 2, ActionKind.convertToPNG.rawValue: 3])
    #expect(placed.map(\.action.kind) == [.convertToJPEG, .convertToPNG, .videoToMP4])
    #expect(placed.map(\.hour) == [2, 3, 4])
}

@Test func actionsWithoutAnHourSpreadOverTheFreeHours() {
    let texts = [text("Oui"), text("Tests"), text("Explique"), text("Stop")]
    let paste = SnippetCatalog.pasteAction
    let placed = RingHours.place([paste] + texts, hours: RingHours.textDefaults)
    #expect(placed.map(\.hour) == [0, 1, 3, 6, 9])
    #expect(placed[0].action.kind == .paste)
    #expect(placed.map(\.action.shortLabel).dropFirst() == ["Oui", "Tests", "Explique", "Stop"])   // l'ordre des réglages
    #expect(RingHours.place(texts, hours: [:]).map(\.hour) == [0, 3, 6, 9])
}

@Test func aChosenHourPinsATextAndTheOthersFillAround() {
    let texts = [text("A"), text("B"), text("C")]
    let placed = RingHours.place(texts, hours: [texts[2].id: 0])
    #expect(placed.map(\.action.shortLabel) == ["C", "A", "B"])
    #expect(placed.map(\.hour) == [0, 1, 6])
}

@Test func layoutGivesTheRingItsAnglesAndEqualSectorsBeyondTwelve() {
    let layout = RingHours.layout([action(.openTerminal), action(.goUp)], hours: RingHours.fileDefaults)
    #expect(layout.actions.map(\.kind) == [.goUp, .openTerminal])
    #expect(layout.angles == [-90, 180])
    let many = (0..<13).map { text("\($0)") }
    let crowded = RingHours.layout(many, hours: [:])
    #expect(crowded.actions == many)
    #expect(crowded.angles.count == 13)
    #expect(abs(crowded.angles[1] - crowded.angles[0] - 360 / 13) < 1e-9)
}

@Test func aSparseRingSpreadsNeighboursApartAroundTheirHours() {
    // Chemin copié à 11 h, Coller à 12 h, un texte à 1 h, un autre à 6 h : les trois du haut se tassaient.
    let spread = RingHours.spread([-120, -90, -60, 90])
    #expect(spread == [-162, -90, -18, 90])
    #expect(RingHours.minimumGap(count: 4) == 72)
}

@Test func aDenseRingKeepsEveryHourExactly() {
    let hours = [0, 1, 2, 3, 4, 5, 8, 9].map(RingHours.angle(of:))   // photos HEIC dans une fenêtre
    #expect(RingHours.spread(hours) == hours)
    #expect(RingHours.minimumGap(count: 8) == 30)
    #expect(RingHours.minimumGap(count: 12) == 30)
}

@Test func spreadingKeepsTheOrderAndTheMinimumGap() {
    // Anneau du dossier : Remonter 12 h, Chemin 5 h, Dossier 7 h, Éditeur 8 h, Terminal 9 h.
    let angles = [0, 5, 7, 8, 9].map(RingHours.angle(of:))
    let spread = RingHours.spread(angles)
    let gap = RingHours.minimumGap(count: 5)
    #expect(gap == 60)
    let sorted = spread.indices.sorted { RingGeometry.normalized(spread[$0]) < RingGeometry.normalized(spread[$1]) }
    #expect(sorted == angles.indices.sorted { RingGeometry.normalized(angles[$0]) < RingGeometry.normalized(angles[$1]) })
    for (i, index) in sorted.enumerated() {
        let next = spread[sorted[(i + 1) % sorted.count]]
        #expect(RingGeometry.normalized(next - spread[index]) >= gap - 0.01)
    }
    #expect(abs(spread[0] + 84) < 0.01)   // Remonter, poussé de 6° par la chaîne, reste en haut
}
