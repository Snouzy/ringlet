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
    static func quoted(_ url: URL) -> String { quoted(url.path) }

    static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
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

    /// ⌘↑ sur la fenêtre du Finder qui montre `item` : la plus profonde dont le dossier contient ce chemin (un
    /// dossier se donne avec son « / » final, pour viser sa propre fenêtre). Elle passe au parent du dossier qu'elle
    /// affiche, même si l'élément est plus bas dans une liste dépliée. Sans fenêtre qui le montre, la fenêtre de devant
    /// (ou une nouvelle) affiche le parent de `fallback`. Sans effet à la racine du disque.
    @MainActor static func goUp(showing item: String, fallback: URL) -> Result<Void, Failure> {
        let parent = fallback.deletingLastPathComponent()
        return run("""
        tell application "Finder"
            set best to missing value
            set bestLength to 0
            -- Par index : « repeat with w in Finder windows » donne des références que le Finder ne résout pas.
            repeat with i from 1 to (count of Finder windows)
                try
                    set w to Finder window i
                    set shown to POSIX path of (target of w as alias)
                    if \(quoted(item)) starts with shown and (length of shown) > bestLength then
                        set best to w
                        set bestLength to length of shown
                    end if
                end try
            end repeat
            if best is not missing value then
                try
                    set target of best to container of (target of best)
                end try
                return
            end if
            if \(quoted(parent)) is \(quoted(fallback)) then return
            -- « up » est un mot réservé du Finder : un autre nom pour le dossier parent.
            set parentFolder to (POSIX file \(quoted(parent)) as alias)
            if (count of Finder windows) is 0 then
                open parentFolder
            else
                set target of front Finder window to parentFolder
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
