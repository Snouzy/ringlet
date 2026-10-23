import AppKit
import RingletCore
import SwiftUI

/// Captures du README, rendues hors écran avec les vraies vues de l'anneau et des réglages :
/// `Ringlet --screenshots <dossier>` (voir `scripts/screenshots.sh`). Rien ne s'affiche, l'app quitte ensuite.
@MainActor enum Screenshots {
    static func runIfAsked() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--screenshots"), args.indices.contains(flag + 1) else { return }
        let dir = URL(fileURLWithPath: args[flag + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let photo = [URL(fileURLWithPath: "/Users/exemple/Desktop/vacances/IMG_8271.HEIC")]
        let photoActions = ActionCatalog.actions(for: photo, terminal: "Ghostty", editor: "Visual Studio Code", canGoUp: true)
        let folderActions = ActionCatalog.folderActions(isDesktop: false, terminal: "Ghostty", editor: "Visual Studio Code")

        render(Scene(dark: true, look: RingLook(style: .glass), actions: photoActions, hot: 1), size: CGSize(width: 1280, height: 760),
               dark: true, to: dir.appendingPathComponent("hero.png"))
        render(StylesBoard(actions: photoActions), size: CGSize(width: 1280, height: 980), dark: false,
               to: dir.appendingPathComponent("styles.png"))
        render(Scene(dark: false, look: RingLook(style: .glass), actions: folderActions, hot: 0, selected: nil),
               size: CGSize(width: 1280, height: 760), dark: false, to: dir.appendingPathComponent("folder.png"))
        let prefs = Preferences(defaults: UserDefaults(suiteName: "io.snouzy.ringlet.screenshots") ?? .standard)
        render(SettingsShot(prefs: prefs), size: CGSize(width: SettingsWindow.width, height: 748), dark: true,
               to: dir.appendingPathComponent("settings.png"))
        exit(0)
    }

    private static func render(_ view: some View, size: CGSize, dark: Bool, to url: URL) {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height)
            .environment(\.colorScheme, dark ? .dark : .light))
        host.frame = NSRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Fond d'écran façon macOS, une fenêtre du Finder, et l'anneau ouvert sur le fichier sélectionné.
private struct Scene: View {
    var dark: Bool
    var look: RingLook
    var actions: [FileAction]
    var hot: Int?
    var selected: Int? = 1
    var ringAt = CGPoint(x: 0.56, y: 0.47)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Backdrop(dark: dark)
                MockFinder(selected: selected)
                    .frame(width: proxy.size.width * 0.74, height: proxy.size.height * 0.78)
                    .position(x: proxy.size.width * 0.45, y: proxy.size.height * 0.5)
                RingFace(actions: actions, geometry: .standard(count: actions.count, size: .large), hot: hot,
                         cancelHot: false, isOpen: true, look: look)
                    .position(x: proxy.size.width * ringAt.x, y: proxy.size.height * ringAt.y)
            }
        }
    }
}

/// Les deux styles, en clair et en sombre.
private struct StylesBoard: View {
    var actions: [FileAction]

    var body: some View {
        Grid(horizontalSpacing: 0, verticalSpacing: 0) {
            GridRow {
                tile(.glass, dark: false, hot: 1)
                tile(.glass, dark: true, hot: 2)
            }
            GridRow {
                tile(.dial, dark: false, hot: 3)
                tile(.dial, dark: true, hot: 4)
            }
        }
    }

    private func tile(_ style: RingStyle, dark: Bool, hot: Int) -> some View {
        Scene(dark: dark, look: RingLook(style: style), actions: actions, hot: hot, ringAt: CGPoint(x: 0.5, y: 0.45))
            .environment(\.colorScheme, dark ? .dark : .light)
            .clipped()
    }
}

/// La rubrique Apparence sous une barre d'outils dessinée comme celle de la vraie fenêtre (la barre d'outils
/// d'AppKit ne passe pas dans un rendu hors écran).
private struct SettingsShot: View {
    var prefs: Preferences

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                ZStack {
                    Text("Apparence").font(.system(size: 13, weight: .semibold))
                    HStack(spacing: 8) {
                        ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                            Circle().fill($0).frame(width: 12, height: 12)
                        }
                        Spacer()
                    }
                    .padding(.leading, 14)
                }
                .frame(height: 28)
                HStack(spacing: 4) {
                    ForEach(SettingsWindow.sections, id: \.title) { section in
                        let isOn = section.title == "Apparence"
                        VStack(spacing: 3) {
                            Image(systemName: section.symbol).font(.system(size: 18))
                            Text(section.title).font(.system(size: 11))
                        }
                        .foregroundStyle(isOn ? Color.accentColor : .secondary)
                        .frame(minWidth: 70)
                        .padding(.vertical, 5)
                        .background(isOn ? Color.primary.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 7))
                    }
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 8)
            .frame(maxWidth: .infinity)
            .background(.bar)
            .overlay(alignment: .bottom) { Divider() }
            AppearanceTab(prefs: prefs, hot: 1)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct Backdrop: View {
    var dark: Bool

    var body: some View {
        if dark {
            ZStack {
                Color(red: 0.05, green: 0.06, blue: 0.12)
                RadialGradient(colors: [Color(red: 0.13, green: 0.26, blue: 0.52), .clear], center: .topLeading, startRadius: 0, endRadius: 900)
                RadialGradient(colors: [Color(red: 0.32, green: 0.13, blue: 0.4), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 850)
            }
        } else {
            ZStack {
                LinearGradient(colors: [Color(red: 0.93, green: 0.95, blue: 0.99), Color(red: 0.97, green: 0.93, blue: 0.91)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color(red: 0.76, green: 0.85, blue: 0.99), .clear], center: .topLeading, startRadius: 0, endRadius: 800)
                RadialGradient(colors: [Color(red: 1, green: 0.82, blue: 0.73), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 750)
            }
        }
    }
}

/// Fenêtre du Finder dessinée en SwiftUI : barre d'outils, barre latérale, liste.
private struct MockFinder: View {
    var selected: Int?
    private let rows: [(String, String, String, String, Bool)] = [
        ("IMG_8268.HEIC", "aujourd'hui à 10:12", "2,1 Mo", "Image HEIF", false),
        ("IMG_8271.HEIC", "aujourd'hui à 10:14", "1,5 Mo", "Image HEIF", false),
        ("IMG_8274.HEIC", "aujourd'hui à 10:21", "1,8 Mo", "Image HEIF", false),
        ("plage.MOV", "hier à 18:40", "84,2 Mo", "Film QuickTime", false),
        ("itinéraire.pdf", "hier à 09:03", "312 ko", "Document PDF", false),
        ("notes", "12 août 2026 à 22:15", "--", "Dossier", true),
        ("IMG_8201.jpg", "11 août 2026 à 16:47", "2,4 Mo", "Image JPEG", false),
        ("IMG_8202.jpg", "11 août 2026 à 16:48", "2,2 Mo", "Image JPEG", false),
    ]

    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 190)
            VStack(spacing: 0) {
                toolbar
                header
                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    line(row, index: index)
                }
                Spacer(minLength: 0)
            }
            .background(Color(nsColor: .textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 16)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34), Color(red: 1, green: 0.74, blue: 0.18), Color(red: 0.16, green: 0.78, blue: 0.25)], id: \.self) {
                    Circle().fill($0).frame(width: 12, height: 12)
                }
            }
            .padding(.bottom, 10)
            Text("Favoris").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            ForEach([("clock", "Récents"), ("square.grid.2x2", "Applications"), ("menubar.dock.rectangle", "Bureau"),
                     ("doc", "Documents"), ("arrow.down.circle", "Téléchargements"), ("photo", "Images")], id: \.1) { symbol, name in
                Label(name, systemImage: symbol).font(.system(size: 13)).foregroundStyle(name == "Bureau" ? Color.accentColor : .primary)
            }
            Text("Emplacements").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary).padding(.top, 6)
            Label("iCloud Drive", systemImage: "icloud").font(.system(size: 13))
            Label("Macintosh HD", systemImage: "internaldrive").font(.system(size: 13))
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.regularMaterial)
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Image(systemName: "chevron.left").foregroundStyle(.secondary)
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            Text("vacances").font(.system(size: 14, weight: .bold))
            Spacer()
            Image(systemName: "list.bullet")
            Image(systemName: "square.and.arrow.up")
            Image(systemName: "magnifyingglass")
        }
        .font(.system(size: 14))
        .padding(.horizontal, 18)
        .frame(height: 52)
    }

    private var header: some View {
        columns("Nom", "Date de modification", "Taille", "Type")
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) { Divider() }
    }

    private func line(_ row: (String, String, String, String, Bool), index: Int) -> some View {
        let isSelected = index == selected
        return HStack(spacing: 8) {
            Image(systemName: row.4 ? "folder.fill" : "doc.fill")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? Color.white : (row.4 ? Color.accentColor : Color.secondary))
            columns(row.0, row.1, row.2, row.3)
        }
        .font(.system(size: 13))
        .foregroundStyle(isSelected ? Color.white : .primary)
        .padding(.leading, 14)
        .padding(.vertical, 5)
        .background(isSelected ? Color.accentColor : (index.isMultiple(of: 2) ? Color.primary.opacity(0.03) : .clear),
                    in: RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
    }

    private func columns(_ a: String, _ b: String, _ c: String, _ d: String) -> some View {
        HStack(spacing: 0) {
            Text(a).frame(maxWidth: .infinity, alignment: .leading)
            Text(b).frame(width: 190, alignment: .leading)
            Text(c).frame(width: 80, alignment: .trailing).padding(.trailing, 20)
            Text(d).frame(width: 130, alignment: .leading)
        }
        .lineLimit(1)
    }
}
