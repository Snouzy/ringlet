import AppKit
import RingletCore

/// Services « Convertir en JPG / PNG avec Ringlet », proposés par le Finder dans le menu du clic droit.
@MainActor final class ServiceProvider: NSObject {
    var onRun: (ActionKind, [URL]) -> Void = { _, _ in }

    @objc func convertToJPEG(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.convertToJPEG, pasteboard)
    }

    @objc func convertToPNG(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        handle(.convertToPNG, pasteboard)
    }

    private func handle(_ kind: ActionKind, _ pasteboard: NSPasteboard) {
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let usable = urls.filter { ActionCatalog.actions(for: [$0], terminal: "").contains { $0.kind == kind } }
        if !usable.isEmpty { onRun(kind, usable) }
    }
}
