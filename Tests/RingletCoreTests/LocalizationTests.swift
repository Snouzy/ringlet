import Foundation
import Testing

/// Le catalogue `Resources/Localizable.xcstrings` (rempli par `scripts/build-app.sh`) : chaque texte de l'app a sa
/// traduction française, avec les mêmes `%@` / `%lld` que l'anglais.
private func loadCatalog() -> [String: Any] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../Resources/Localizable.xcstrings").standardizedFileURL
    let data = (try? Data(contentsOf: url)) ?? Data()
    return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
}

private func specifiers(_ text: String) -> [String] {
    let regex = try! NSRegularExpression(pattern: "%(lld|@|%)")
    return regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        .map { (text as NSString).substring(with: $0.range) }.sorted()
}

@Test func everyStringHasAFrenchTranslation() throws {
    let strings = try #require(loadCatalog()["strings"] as? [String: [String: Any]])
    #expect(strings.count > 50)
    for (key, entry) in strings where entry["extractionState"] as? String != "stale" {
        let fr = (entry["localizations"] as? [String: Any])?["fr"] as? [String: Any]
        let unit = fr?["stringUnit"] as? [String: String]
        #expect(unit?["state"] == "translated", "Pas de français pour « \(key) »")
        if let value = unit?["value"] { #expect(specifiers(value) == specifiers(key), "« \(key) » → « \(value) »") }
    }
}
