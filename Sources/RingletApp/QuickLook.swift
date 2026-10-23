import AppKit
import Quartz

/// Coup d'œil sur les fichiers, comme Espace dans le Finder. Ringlet n'a pas de fenêtre dans la chaîne des
/// répondeurs pour piloter le panneau : on lui donne directement sa source.
@MainActor final class QuickLook: NSObject, @preconcurrency QLPreviewPanelDataSource {
    static let shared = QuickLook()
    private var urls: [URL] = []

    func show(_ urls: [URL]) {
        guard !urls.isEmpty, let panel = QLPreviewPanel.shared() else { return }
        self.urls = urls
        // Ringlet est une app de barre des menus : il faut l'activer pour que Échap et Espace ferment l'aperçu.
        NSApp.activate()
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = 0
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { urls.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        urls[index] as NSURL
    }
}
