import AppKit

/// Petites commandes envoyées au Finder par Apple Events (autorisation Automatisation › Finder).
enum FinderScript {
    enum Failure: Error, Equatable {
        case notAuthorized
        case failed
    }

    @MainActor @discardableResult
    static func run(_ source: String) -> Result<NSAppleEventDescriptor, Failure> {
        guard let script = NSAppleScript(source: source) else { return .failure(.failed) }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            // -1743 : accès au Finder refusé, ou pas encore accordé.
            return .failure((error[NSAppleScript.errorNumber] as? Int) == -1743 ? .notAuthorized : .failed)
        }
        return .success(result)
    }

    /// Chemin écrit dans une chaîne AppleScript.
    static func quoted(_ url: URL) -> String {
        "\"" + url.path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    /// Dossier affiché par la fenêtre Finder de devant ; le bureau s'il n'y a pas de fenêtre.
    @MainActor static func frontFolder() -> Result<(url: URL, isDesktop: Bool), Failure> {
        let source = """
        tell application "Finder"
            if (count of Finder windows) is 0 then return {POSIX path of (desktop as alias), "bureau"}
            return {POSIX path of (target of front Finder window as alias), "fenêtre"}
        end tell
        """
        return run(source).flatMap { descriptor in
            guard let path = descriptor.atIndex(1)?.stringValue else { return .failure(.failed) }
            return .success((URL(fileURLWithPath: path, isDirectory: true), descriptor.atIndex(2)?.stringValue == "bureau"))
        }
    }

    /// Affiche le parent de `folder` dans la fenêtre Finder de devant, ou dans une nouvelle s'il n'y en a pas
    /// (sans effet à la racine du disque).
    @MainActor static func goUp(from folder: URL) -> Result<Void, Failure> {
        let parent = folder.deletingLastPathComponent()
        guard parent.standardizedFileURL.path != folder.standardizedFileURL.path else { return .success(()) }
        return run("""
        tell application "Finder"
            set up to (POSIX file \(quoted(parent)) as alias)
            if (count of Finder windows) is 0 then
                open up
            else
                set target of front Finder window to up
            end if
        end tell
        """).map { _ in }
    }

    /// Crée « dossier sans titre » (nom donné par le Finder, annulable par ⌘Z) dans `folder` et le sélectionne.
    @MainActor static func newFolder(in folder: URL) -> Result<Void, Failure> {
        run("""
        tell application "Finder"
            activate
            set created to make new folder at (POSIX file \(quoted(folder)) as alias)
            select created
        end tell
        """).map { _ in }
    }
}
