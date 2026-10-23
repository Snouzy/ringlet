import Testing
@testable import RingletCore

@Test func glassOpacityStaysReadable() {
    #expect(GlassOpacity.clamped(0) == 0.3)
    #expect(GlassOpacity.clamped(1) == 0.95)
    #expect(GlassOpacity.clamped(GlassOpacity.standard) == 0.72)
}

@Test func onlySystemAccentFollowsMacOS() {
    #expect(RingAccent.allCases.filter { $0.rgb == nil } == [.system])
    #expect(RingAccent.blue.rgb == 0x007AFF)
}

@Test func stylesSurviveTheirSavedName() {
    #expect(RingStyle.allCases.map { RingStyle(rawValue: $0.rawValue) } == [.glass, .dial])
    #expect(RingStyle.allCases.map(\.label) == ["Verre", "Cadran"])
}
