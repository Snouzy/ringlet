import Foundation
import Testing
@testable import RingletCore

private let drive = "/Users/m/Drive"

@Test func goingUpOffersToComeBackDown() {
    var d = Descent()
    d.wentUp(from: "\(drive)/3D print/poignees/", to: "\(drive)/3D print/", item: "\(drive)/3D print/poignees/a.stl")
    let step = d.step(showing: "\(drive)/3D print")
    #expect(step?.child == "\(drive)/3D print/poignees")
    #expect(step?.item == "\(drive)/3D print/poignees/a.stl")
    #expect(Descent.action(for: step!).kind == .goDown)
    #expect(d.step(showing: drive) == nil)
}

@Test func severalLevelsComeBackOneByOne() {
    var d = Descent()
    d.wentUp(from: "\(drive)/a/b", to: "\(drive)/a", item: nil)
    d.wentUp(from: "\(drive)/a", to: drive, item: nil)
    #expect(d.step(showing: drive)?.child == "\(drive)/a")
    d.wentDown()
    #expect(d.step(showing: "\(drive)/a")?.child == "\(drive)/a/b")
    d.wentDown()
    #expect(d.step(showing: "\(drive)/a/b") == nil)
}

@Test func goingElsewhereForgetsTheWayDown() {
    var d = Descent()
    d.wentUp(from: "\(drive)/a/b", to: "\(drive)/a", item: nil)
    d.sync(showing: "/Users/m/Downloads")
    #expect(d.steps.isEmpty)
    #expect(d.step(showing: "\(drive)/a") == nil)
}

@Test func aNewClimbFromSomewhereElseStartsOver() {
    var d = Descent()
    d.wentUp(from: "\(drive)/a/b", to: "\(drive)/a", item: nil)
    d.wentUp(from: "/tmp/x/y", to: "/tmp/x", item: nil)
    #expect(d.steps.count == 1)
    #expect(d.step(showing: "/tmp/x")?.child == "/tmp/x/y")
}

@Test func downSitsAtTheBottomOfTheRing() {
    let a = (0..<5).map { FileAction(kind: .copyPath, shortLabel: "\($0)", label: "\($0)") }
    let down = FileAction(kind: .goDown, shortLabel: "D", label: "D")
    let ring = Descent.inserting(down, into: a)
    let index = ring.firstIndex { $0.kind == .goDown }!
    #expect(RingGeometry.standard(count: ring.count).centerAngle(of: index) == 90)   // tout en bas
    let odd = Descent.inserting(down, into: Array(a.prefix(4)))
    let angle = RingGeometry.standard(count: odd.count).centerAngle(of: odd.firstIndex { $0.kind == .goDown }!)
    #expect(abs(angle - 90) <= 360 / Double(odd.count) / 2)   // le secteur le plus proche du bas
}
