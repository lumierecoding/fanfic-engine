import AppKit
import SwiftUI

@main
struct FanficEngineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @State private var updater = AppUpdater.shared

    /// 1100 × 700 (ui-spec U1). Developer option `-windowSize 1100x1000` for screenshots.
    private static var windowSize: CGSize {
        let parts = (UserDefaults.standard.string(forKey: "windowSize") ?? "").split(separator: "x").compactMap { Double($0) }
        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : CGSize(width: 1100, height: 700)
    }

    var body: some Scene {
        Window("Fanfic Engine", id: "main") {
            ContentView(model: model)
        }
        .defaultSize(Self.windowSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Files…") { model.addFilesWithPanel() }
                    .keyboardShortcut("o")
            }
            CommandGroup(after: .newItem) {
                Divider()
                Button("Re-read Library") { model.rereadLibrary() }
                    .disabled(model.library.isBusy || model.library.works.isEmpty)
                Button("Show Library in Finder") { model.showLibraryInFinder() }
            }
            CheckForUpdatesCommand(updater: updater)
        }

        Settings {
            SettingsView(model: model, updater: updater)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if AppModel.startup.oldAppIsRunning {
            // The library is still in the old app's folder and that app is open: don't move it under its feet.
            let alert = NSAlert()
            alert.messageText = "Please quit Fanfic Pairings first"
            alert.informativeText = "Fanfic Engine is the new name of Fanfic Pairings. Quit Fanfic Pairings, then open Fanfic Engine again: your library and settings are moved over automatically."
            alert.addButton(withTitle: "Quit")
            NSApp.activate()
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        // Developer option `-appearance light|dark` (screenshots); otherwise the system setting is used.
        switch UserDefaults.standard.string(forKey: "appearance") {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        AppUpdater.shared.start()

        // Developer option `-dumpMenus <file>`: writes the menu bar as text (to check the menus without clicking).
        if let path = UserDefaults.standard.string(forKey: "dumpMenus") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                var lines: [String] = []
                for item in NSApp.mainMenu?.items ?? [] {
                    lines.append(item.title)
                    for sub in item.submenu?.items ?? [] {
                        lines.append(sub.isSeparatorItem ? "  ——" : "  " + sub.title + (sub.isEnabled ? "" : " (greyed out)"))
                    }
                }
                try? lines.joined(separator: "\n").write(toFile: (path as NSString).expandingTildeInPath, atomically: true, encoding: .utf8)
            }
        }
        // Developer option `-windowFrame "x y width height"` (screen points, origin bottom left): moves the window there
        // once it is open, for example onto a Retina display for screenshots at 2x. A negative x needs a leading space
        // (`-windowFrame " -1410 150 1100 700"`), or it is read as an option name.
        if let numbers = UserDefaults.standard.string(forKey: "windowFrame")?.split(separator: " ").compactMap({ Double($0) }),
           numbers.count == 4 {
            let frame = NSRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
            func place(_ attempt: Int) {
                if let window = NSApp.windows.first(where: { $0.isVisible && $0.title == "Fanfic Engine" }) {
                    window.setFrame(frame, display: true)
                } else if attempt < 20 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { place(attempt + 1) }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { place(0) }
        }
        // Developer option `-showAppMenu YES`: opens the app menu under the window's top-left corner (screenshots).
        if UserDefaults.standard.bool(forKey: "showAppMenu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                guard let menu = NSApp.mainMenu?.items.first?.submenu,
                      let view = NSApp.windows.first(where: { $0.isVisible && $0.title == "Fanfic Engine" })?.contentView else { return }
                menu.popUp(positioning: nil, at: NSPoint(x: 12, y: view.bounds.height - 12), in: view)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Files dropped on the Dock icon or opened with "Open With → Fanfic Engine".
    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.importFiles(urls)
    }
}
