import AppKit
import Observation
@preconcurrency import Sparkle
import SwiftUI

/// Updates inside the app with Sparkle (SPEC section 10, ui-spec change 8).
///
/// Sparkle is the app's only network code, and it only talks to GitHub: the feed is `SUFeedURL` in Info.plist, and an
/// update is installed only if it is signed with the key whose public half is `SUPublicEDKey`. Info.plist has no
/// `SUEnableAutomaticChecks`, so Sparkle asks on the second start whether to check automatically; until then it never
/// checks on its own (U44).
@MainActor
@Observable
final class AppUpdater: NSObject {
    static let shared = AppUpdater()

    @ObservationIgnored private var controller: SPUStandardUpdaterController!
    @ObservationIgnored private var observations: [NSKeyValueObservation] = []

    /// False while a check or an update is running: the menu item and Check Now are greyed out then.
    private(set) var canCheckForUpdates = false
    /// When the last check ran (nil: never).
    private(set) var lastCheck: Date?
    /// The Settings switch. The same setting as the answer to Sparkle's question on the second start.
    var automaticallyChecks = false {
        didSet {
            guard let updater, updater.automaticallyChecksForUpdates != automaticallyChecks else { return }
            updater.automaticallyChecksForUpdates = automaticallyChecks
        }
    }

    private var updater: SPUUpdater? { controller?.updater }

    private override init() {
        super.init()
        // Not started here: the app may still quit at launch ("Please quit Fanfic Pairings first").
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil)
    }

    /// Starts Sparkle once the app is really running (called from the app delegate).
    func start() {
        guard let controller else { return }
        controller.startUpdater()
        let updater = controller.updater
        observations = [
            updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] _, change in
                let value = change.newValue ?? false
                Task { @MainActor in self?.canCheckForUpdates = value }
            },
        ]
        refresh()

        // Developer options for the update tests (a test copy with its own bundle ID, never the real app):
        // `-checkForUpdatesOnLaunch YES` opens Sparkle's check as if Check for Updates… was chosen;
        // `-checkInBackgroundOnLaunch YES` checks quietly, as an automatic check would.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "checkForUpdatesOnLaunch") {
            controller.checkForUpdates(nil)
        } else if defaults.bool(forKey: "checkInBackgroundOnLaunch") {
            updater.checkForUpdatesInBackground()
        }
    }

    /// Check for Updates… (app menu) and Check Now (Settings).
    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    /// Reads Sparkle's settings again (they can change through Sparkle's own question).
    func refresh() {
        guard let updater else { return }
        if automaticallyChecks != updater.automaticallyChecksForUpdates {
            automaticallyChecks = updater.automaticallyChecksForUpdates
        }
        lastCheck = updater.lastUpdateCheckDate
    }
}

extension AppUpdater: SPUUpdaterDelegate {
    /// Developer option `-installUpdatesImmediately YES` (update tests): an update that was downloaded in the
    /// background is installed and the app started again right away, as **Install and Relaunch** does.
    func updater(_ updater: SPUUpdater, willInstallUpdateOnQuit item: SUAppcastItem,
                 immediateInstallationBlock immediateInstallHandler: @escaping () -> Void) -> Bool {
        guard UserDefaults.standard.bool(forKey: "installUpdatesImmediately") else { return false }
        immediateInstallHandler()
        return true
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        refresh()
    }
}

/// App menu → Check for Updates…, directly after About Fanfic Engine (U41).
struct CheckForUpdatesCommand: Commands {
    let updater: AppUpdater

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") { updater.checkForUpdates() }
                .disabled(!updater.canCheckForUpdates)
        }
    }
}
