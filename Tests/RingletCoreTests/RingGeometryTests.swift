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

@Test func sectorFollowsDirectionInsideTheRing() {
    let ring = RingGeometry(count: 4, radius: 84, deadZone: 16)
    // Coordonnées écran : y vers le bas, donc « en haut » = dy négatif.
    #expect(ring.sector(dx: 0, dy: -30) == 0)
    #expect(ring.sector(dx: 90, dy: 10) == 1)
    #expect(ring.sector(dx: -5, dy: 80) == 2)
    #expect(ring.sector(dx: -40, dy: 0) == 3)
}

@Test func outsideTheRingSelectsNothing() {
    let ring = RingGeometry(count: 4, radius: 84, deadZone: 16)
    #expect(ring.reach == 96)
    #expect(ring.sector(dx: 0, dy: -96) == 0)
    #expect(ring.sector(dx: 0, dy: -97) == nil)
    #expect(ring.sector(dx: 300, dy: 10) == nil)
    #expect(ring.isAiming(dx: 300, dy: 10))
    #expect(!ring.isAiming(dx: 5, dy: 5))
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

@Test func unevenSectorsReachHalfwayToTheirNeighbours() {
    // Remonter à 12 h, Terminal à 9 h, Chemin à 5 h : chaque secteur va jusqu'à mi-chemin du voisin.
    let ring = RingGeometry(angles: [-90, 180, 60], radius: 84, deadZone: 16)
    #expect(ring.count == 3)
    #expect(ring.centerAngle(of: 0) == -90)
    #expect(ring.bounds(of: 0) == (start: -135, end: -15))    // entre 9 h et 12 h, puis entre 12 h et 5 h
    #expect(ring.bounds(of: 1) == (start: 120, end: 225))     // 5 h → 9 h, 9 h → 12 h
    #expect(ring.bounds(of: 2) == (start: -15, end: 120))
    #expect(ring.sector(dx: 30, dy: -30) == 0)      // 1 h 30 : encore Remonter
    #expect(ring.sector(dx: 30, dy: 10) == 2)       // 3 h 30 : Chemin
    #expect(ring.sector(dx: -30, dy: 30) == 1)      // 7 h 30 : Terminal
    #expect(ring.sector(dx: -30, dy: -25) == 1)     // 10 h 20 : Terminal, pas encore Remonter
    #expect(ring.sector(dx: -30, dy: -35) == 0)     // 10 h 40 : Remonter
}

@Test func aSingleSectorCoversTheWholeRing() {
    let ring = RingGeometry(angles: [90], radius: 84, deadZone: 16)
    #expect(ring.sector(dx: 0, dy: -50) == 0)
    #expect(ring.sector(dx: 50, dy: 0) == 0)
    #expect(ring.bounds(of: 0).end - ring.bounds(of: 0).start == 360)
}

@Test func equalSectorsAreTheSameWhateverTheInitializer() {
    let equal = RingGeometry(count: 4, radius: 84, deadZone: 16)
    let angled = RingGeometry(angles: [-90, 0, 90, 180], radius: 84, deadZone: 16)
    #expect(equal == angled)
    #expect(equal.bounds(of: 1) == (start: -45, end: 45))
}
