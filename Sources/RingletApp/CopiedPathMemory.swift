import AppKit
import RingletCore

/// Retient le dernier chemin copié, pour le proposer même après avoir copié autre chose (gardé d'un lancement
/// à l'autre). Regarde seulement le compteur du presse-papiers ; le contenu n'est lu que quand il change.
@MainActor final class CopiedPathMemory {
    private static let key = "lastCopiedPath"
    private var changeCount = -1
    /// Chemin dans le presse-papiers au dernier changement.
    private var current: URL?
    private var timer: Timer?

    private var remembered: URL? {
        get { UserDefaults.standard.string(forKey: Self.key).map { URL(fileURLWithPath: $0) } }
        set { UserDefaults.standard.set(newValue?.path, forKey: Self.key) }
    }

    func start() {
        poll()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = 0.3
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Le chemin du presse-papiers, sinon le dernier copié s'il existe encore.
    var latest: URL? {
        poll()
        return ClipboardPath.choose(current: current, remembered: remembered)
    }

    private func poll() {
        let count = NSPasteboard.general.changeCount
        guard count != changeCount else { return }
        changeCount = count
        current = Self.read()
        if let current { remembered = current }
    }

    /// Texte, ou fichier copié dans le Finder avec ⌘C. Les types d'abord : le contenu seulement s'il peut être un chemin.
    private static func read() -> URL? {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        if types.contains(.fileURL),
           let url = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL])?.first,
           FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        guard types.contains(.string), let text = pasteboard.string(forType: .string) else { return nil }
        return ClipboardPath.url(from: text)
    }
}
