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
