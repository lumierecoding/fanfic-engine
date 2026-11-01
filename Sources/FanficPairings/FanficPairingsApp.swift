import AppKit
import SwiftUI

@main
struct FanficPairingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared

    /// 1100 × 700 (ui-spec U1). Developer option `-windowSize 1100x1000` for screenshots.
    private static var windowSize: CGSize {
        let parts = (UserDefaults.standard.string(forKey: "windowSize") ?? "").split(separator: "x").compactMap { Double($0) }
        return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : CGSize(width: 1100, height: 700)
    }

    var body: some Scene {
        Window("Fanfic Pairings", id: "main") {
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
        }

        Settings {
            SettingsView(model: model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Developer option `-appearance light|dark` (screenshots); otherwise the system setting is used.
        switch UserDefaults.standard.string(forKey: "appearance") {
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        default: break
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Files dropped on the Dock icon or opened with "Open With → Fanfic Pairings".
    func application(_ application: NSApplication, open urls: [URL]) {
        AppModel.shared.importFiles(urls)
    }
}
