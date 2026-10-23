import AppKit

/// App choisie pour le terminal ou l'éditeur, retrouvée par son identifiant.
struct AppChoice: Hashable, Identifiable {
    var bundleID: String
    var id: String { bundleID }

    var url: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var name: String { url.map { FileManager.default.displayName(atPath: $0.path).replacingOccurrences(of: ".app", with: "") } ?? bundleID }
    var isInstalled: Bool { url != nil }

    static let terminals = ["com.mitchellh.ghostty", "com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable",
                            "com.github.wez.wezterm", "net.kovidgoyal.kitty", "org.alacritty"].map(AppChoice.init)
    static let editors = ["com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "dev.zed.Zed", "com.sublimetext.4",
                          "com.exafunction.windsurf", "com.apple.dt.Xcode"].map(AppChoice.init)

    /// Premier installé de la liste (Ghostty, sinon Terminal ; VS Code, sinon le premier éditeur trouvé).
    static func firstInstalled(_ list: [AppChoice], fallback: String) -> AppChoice {
        list.first(where: \.isInstalled) ?? AppChoice(bundleID: fallback)
    }

    /// Demande une app dans /Applications ; nil si l'utilisateur annule.
    @MainActor static func pick() -> AppChoice? {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.prompt = "Choisir"
        guard panel.runModal() == .OK, let url = panel.url, let id = Bundle(url: url)?.bundleIdentifier else { return nil }
        return AppChoice(bundleID: id)
    }
}
