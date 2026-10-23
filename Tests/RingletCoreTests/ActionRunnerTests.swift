import Foundation
import Testing
@testable import RingletCore

private func result(_ name: String, output: String? = nil, error: ConversionError? = nil) -> ConversionResult {
    ConversionResult(source: URL(fileURLWithPath: "/d/\(name)"), output: output.map { URL(fileURLWithPath: "/d/\($0)") },
                     error: error)
}

@Test func kindsMapToFormats() {
    #expect(ActionKind.convertToJPEG.format(jpegQuality: 0.8) == .jpeg(quality: 0.8))
    #expect(ActionKind.convertToPNG.format(jpegQuality: 0.8) == .png)
    #expect(ActionKind.copyPath.format(jpegQuality: 0.8) == nil)
}

@Test func summaryNamesASingleFile() {
    let s = ResultSummary(results: [result("IMG.heic", output: "IMG.jpg")])
    #expect(s.text == "IMG.jpg created")
    #expect(!s.hasFailures)
}

@Test func summaryCountsSeveralFilesAndFailures() {
    #expect(ResultSummary(results: [result("a.heic", output: "a.jpg"), result("b.heic", output: "b.jpg")]).text
            == "2 files created")
    let mixed = ResultSummary(results: [result("a.heic", output: "a.jpg"), result("b.heic", output: "b.jpg"),
                                        result("c.heic", error: .unreadable)])
    #expect(mixed.text == "2 files created, 1 failure")
    #expect(mixed.hasFailures)
}

@Test func summaryExplainsASingleFailure() {
    #expect(ResultSummary(results: [result("IMG.heic", error: .unreadable)]).text == "IMG.heic can’t be read")
    #expect(ResultSummary(results: [result("IMG.heic", error: .writeFailed)]).text
            == "Can’t write next to IMG.heic")
    #expect(ResultSummary(results: [result("a.heic", error: .unreadable), result("b.heic", error: .writeFailed)]).text
            == "2 failures")
}
