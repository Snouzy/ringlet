import AppKit

/// Fichiers sélectionnés dans le Finder, lus par Apple Events (autorisation Automatisation › Finder).
enum FinderSelection {
    enum Failure: Error, Equatable {
        case notAuthorized
        case unavailable
    }

    @MainActor private static let script: NSAppleScript? = {
        let source = """
        tell application "Finder"
            set picked to selection
            set paths to {}
            repeat with anItem in picked
                set end of paths to POSIX path of (anItem as alias)
            end repeat
            return paths
        end tell
        """
        let script = NSAppleScript(source: source)
        script?.compileAndReturnError(nil)
        return script
    }()

    @MainActor static func read() -> Result<[URL], Failure> {
        guard let script else { return .failure(.unavailable) }
        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)
        if let error {
            // -1743 : l'utilisateur a refusé (ou pas encore accordé) l'accès au Finder.
            return .failure((error[NSAppleScript.errorNumber] as? Int) == -1743 ? .notAuthorized : .unavailable)
        }
        guard descriptor.numberOfItems > 0 else { return .success([]) }
        let urls = (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0)?.stringValue }
            .map { URL(fileURLWithPath: $0) }
        return .success(urls)
    }
}
