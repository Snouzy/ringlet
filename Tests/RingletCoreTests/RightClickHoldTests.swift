import CoreGraphics
import Testing
@testable import RingletCore

@Test func quickClickIsReplayedAsANormalRightClick() {
    var hold = RightClickHold(moveThreshold: 6)
    hold.down(at: CGPoint(x: 100, y: 100))
    #expect(hold.move(to: CGPoint(x: 102, y: 101)) == nil)
    #expect(hold.up() == .replayClick)
    #expect(hold.up() == .passThrough)
}

@Test func holdingOpensTheRingAndReleaseRunsIt() {
    var hold = RightClickHold(moveThreshold: 6)
    hold.down(at: .zero)
    #expect(hold.timerFired() == .openRing)
    #expect(hold.timerFired() == nil)
    #expect(hold.up() == .releaseRing)
}

@Test func movingBeforeTheDelayOpensTheRingAtOnce() {
    var hold = RightClickHold(moveThreshold: 6)
    hold.down(at: CGPoint(x: 10, y: 10))
    #expect(hold.move(to: CGPoint(x: 10, y: 20)) == .openRing)
    #expect(hold.timerFired() == nil)
    #expect(hold.up() == .releaseRing)
}

@Test func upWithoutDownPassesThrough() {
    var hold = RightClickHold(moveThreshold: 6)
    #expect(hold.up() == .passThrough)
    #expect(hold.timerFired() == nil)
}

@Test func ringSizesGrowWithTheChoice() {
    #expect(RingSize.allCases.map(\.radius) == [96, 114, 134])
    #expect(RingGeometry.standard(count: 2, size: .large).radius == 134)
    #expect(RingGeometry.standard(count: 2).radius == 114)
}
