import FanficCore
import SwiftUI

/// The standard macOS Settings window (⌘, or the gear button), ui-spec U19.
/// Everything is stored in the app's preferences on this Mac.
struct SettingsView: View {
    @Bindable var model: AppModel
    @Bindable var updater: AppUpdater

    @AppStorage("showFandoms") private var showFandoms = true
    @AppStorage("showCharacters") private var showCharacters = true
    @AppStorage("showPairings") private var showPairings = true
    @AppStorage("sidebarSort") private var sort = SidebarSort.name
    @AppStorage("includeFriendships") private var includeFriendships = true

    var body: some View {
        Form {
            Section("Sidebar") {
                Toggle("Show Fandoms", isOn: $showFandoms)
                Toggle("Show Characters", isOn: $showCharacters)
                Toggle("Show Pairings", isOn: $showPairings)
                Picker("Sort lists by", selection: $sort) {
                    Text("Name").tag(SidebarSort.name)
                    Text("Number of fanfics").tag(SidebarSort.count)
                }
            }

            Section {
                Toggle("Include friendship tags (A & B)", isOn: $includeFriendships)
            } header: {
                Text("Relationships")
            } footer: {
                Text("When off, A & B tags are left out of Pairings, and people who only appear in them are left out of Characters. Searching is not affected.")
                    .foregroundStyle(.secondary)
            }

            Section("Library") {
                LabeledContent("Folder") {
                    Text(model.library.root.path)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                LabeledContent("Contents") {
                    Text(contents)
                }
                HStack {
                    Spacer()
                    Button("Show in Finder") { model.showLibraryInFinder() }
                    Button("Re-read Library") { model.rereadLibrary() }
                        .disabled(model.library.isBusy || model.library.works.isEmpty)
                }
            }

            // Updates (ui-spec change 8, U42): Sparkle's settings; the app's only connection is to GitHub.
            Section {
                Toggle("Check for updates automatically", isOn: $updater.automaticallyChecks)
                LabeledContent("Last checked") {
                    Text(updater.lastCheck.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                }
                HStack {
                    Spacer()
                    Button("Check Now") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                }
            } header: {
                Text("Updates")
            } footer: {
                Text("Fanfic Engine only connects to GitHub to look for a new version: when you click Check Now or Check for Updates, or once a day if automatic checks are on. Your fanfics and your library never leave this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { updater.refresh() }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var contents: String {
        let works = model.library.works.count
        let pages = (try? FileManager.default.contentsOfDirectory(atPath: model.library.firstPagesFolder.path))?
            .filter { $0.hasSuffix(".pdf") }.count ?? 0
        return "\(works) \(works == 1 ? "fanfic" : "fanfics") · \(pages) \(pages == 1 ? "first page" : "first pages")"
    }
}
