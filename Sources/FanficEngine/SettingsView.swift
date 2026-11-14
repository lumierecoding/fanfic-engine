import FanficCore
import SwiftUI

/// The Settings window (⌘, or the gear button), ui-spec U19; each group on a glass panel (change 15).
/// Everything is stored in the app's preferences on this Mac.
struct SettingsView: View {
    @Bindable var model: AppModel
    @Bindable var updater: AppUpdater

    @AppStorage("showFandoms") private var showFandoms = true
    @AppStorage("showCharacters") private var showCharacters = true
    @AppStorage("showPairings") private var showPairings = true
    @AppStorage("showTags") private var showTags = true
    @AppStorage("sidebarSort") private var sort = SidebarSort.name
    @AppStorage("includeFriendships") private var includeFriendships = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            group("Sidebar") {
                switchRow("Show Fandoms", isOn: $showFandoms)
                Divider()
                switchRow("Show Characters", isOn: $showCharacters)
                Divider()
                switchRow("Show Pairings", isOn: $showPairings)
                Divider()
                switchRow("Show Tags", isOn: $showTags)
                Divider()
                HStack {
                    Text("Sort lists by")
                    Spacer()
                    Picker("Sort lists by", selection: $sort) {
                        Text("Name").tag(SidebarSort.name)
                        Text("Number of fanfics").tag(SidebarSort.count)
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }

            group("Relationships",
                  footer: "When off, A & B tags are left out of Pairings, and people who only appear in them are left out of Characters. Searching is not affected.") {
                switchRow("Include friendship tags (A & B)", isOn: $includeFriendships)
            }

            group("Library") {
                HStack(alignment: .firstTextBaseline) {
                    Text("Folder")
                    Spacer(minLength: 16)
                    Text(model.library.root.path)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .multilineTextAlignment(.trailing)
                }
                Divider()
                HStack {
                    Text("Contents")
                    Spacer()
                    Text(contents).foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Show in Finder") { model.showLibraryInFinder() }
                        .glassButton()
                    Button("Re-read Library") { model.rereadLibrary() }
                        .glassButton()
                        .disabled(model.library.isBusy || model.library.works.isEmpty)
                }
            }

            // Updates (ui-spec change 8, U42): Sparkle's settings; the app's only connection is to GitHub.
            group("Updates",
                  footer: "Fanfic Engine only connects to GitHub to look for a new version: when you click Check Now or Check for Updates, or once a day if automatic checks are on. Your fanfics and your library never leave this Mac.") {
                switchRow("Check for updates automatically", isOn: $updater.automaticallyChecks)
                Divider()
                HStack {
                    Text("Last checked")
                    Spacer()
                    Text(updater.lastCheck.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Never")
                        .foregroundStyle(.secondary)
                }
                Divider()
                HStack {
                    Spacer()
                    Button("Check Now") { updater.checkForUpdates() }
                        .glassButton()
                        .disabled(!updater.canCheckForUpdates)
                }
            }
        }
        .padding(20)
        .onAppear { updater.refresh() }
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A heading, the rows on a glass panel, and an optional note under it.
    private func group<Content: View>(_ title: String, footer: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .glassPanel(padding: 12, cornerRadius: 14)
            if let footer {
                Text(footer)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// The name on the left, the switch on the right, as in the system's Settings forms.
    private func switchRow(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle(title, isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)  // the size the system's Settings forms use
                .labelsHidden()
        }
    }

    private var contents: String {
        let works = model.library.works.count
        let pages = (try? FileManager.default.contentsOfDirectory(atPath: model.library.firstPagesFolder.path))?
            .filter { $0.hasSuffix(".pdf") }.count ?? 0
        return "\(works) \(works == 1 ? "fanfic" : "fanfics") · \(pages) \(pages == 1 ? "first page" : "first pages")"
    }
}
