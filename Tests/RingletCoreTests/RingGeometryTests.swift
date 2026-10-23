import CoreGraphics
import Testing
@testable import RingletCore

@Test func firstSectorPointsUpAndOthersFollowClockwise() {
    let ring = RingGeometry(count: 4, radius: 84, deadZone: 16)
    #expect(ring.centerAngle(of: 0) == -90)
    #expect(ring.centerAngle(of: 1) == 0)
    #expect(ring.centerAngle(of: 2) == 90)
    #expect(ring.centerAngle(of: 3) == 180)
}

@Test func sectorFollowsDirectionNotDistance() {
    let ring = RingGeometry(count: 4, radius: 84, deadZone: 16)
    // Coordonnées écran : y vers le bas, donc « en haut » = dy négatif.
    #expect(ring.sector(dx: 0, dy: -30) == 0)
    #expect(ring.sector(dx: 300, dy: 10) == 1)
    #expect(ring.sector(dx: -5, dy: 200) == 2)
    #expect(ring.sector(dx: -40, dy: 0) == 3)
}

@Test func deadZoneSelectsNothing() {
    let ring = RingGeometry(count: 2, radius: 84, deadZone: 16)
    #expect(ring.sector(dx: 10, dy: -10) == nil)
    #expect(ring.sector(dx: 0, dy: 0) == nil)
    #expect(ring.sector(dx: 0, dy: -17) == 0)
}

@Test func twoSectorsSplitTopAndBottom() {
    let ring = RingGeometry(count: 2, radius: 84, deadZone: 16)
    #expect(ring.sector(dx: 30, dy: -20) == 0)
    #expect(ring.sector(dx: -30, dy: 20) == 1)
}

@Test func emptyRingSelectsNothing() {
    #expect(RingGeometry(count: 0, radius: 84, deadZone: 16).sector(dx: 0, dy: -50) == nil)
}

@Test func centerIsPushedBackInsideTheScreen() {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)
    #expect(RingGeometry.clampedCenter(CGPoint(x: 500, y: 300), outerRadius: 120, in: screen) == CGPoint(x: 500, y: 300))
    #expect(RingGeometry.clampedCenter(CGPoint(x: 10, y: 590), outerRadius: 120, in: screen) == CGPoint(x: 120, y: 480))
    let narrow = CGRect(x: 0, y: 0, width: 200, height: 600)
    #expect(RingGeometry.clampedCenter(CGPoint(x: 10, y: 300), outerRadius: 120, in: narrow).x == 100)
}
