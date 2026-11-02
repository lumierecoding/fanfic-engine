import FanficCore
import SwiftUI

/// The main window: pairings | works | first page and details (docs/ui-spec.md).
struct ContentView: View {
    @Bindable var model: AppModel
    @State private var isDropTargeted = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
        } content: {
            WorkListView(model: model)
                .titleBand()
                .navigationSplitViewColumnWidth(min: 320, ideal: 420)
        } detail: {
            WorkDetailView(model: model)
                .titleBand()
                .frame(minWidth: 340)
        }
        .hidingSystemTitleBand()
        .navigationTitle("Fanfic Engine")
        .navigationSubtitle(subtitle)
        .searchable(text: $model.searchText, placement: .toolbar, prompt: "Search pairing, e.g. Harry/Draco")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if model.library.isBusy {
                    ProgressView().controlSize(.small)
                }
                Button { model.addFilesWithPanel() } label: {
                    Label("Add Files…", systemImage: "plus")
                }
                .help("Add EPUB or PDF files, or folders")
                Button { model.showLibraryInFinder() } label: {
                    Label("Show Library in Finder", systemImage: "folder")
                }
                .help("Open the library folder (Works, First Pages, library.json)")
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings (⌘,)")
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            model.importFiles(urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted || model.previewDropHighlight { DropHighlight() }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onAppear {
            // Developer option `-openSettings YES` (screenshots).
            if UserDefaults.standard.bool(forKey: "openSettings") { openSettings() }
        }
        .onChange(of: model.sidebarSelection) { model.sidebarChanged() }
        .onChange(of: model.searchText) { model.searchChanged() }
        .sheet(item: $model.reportSheet) { sheet in
            ImportSummaryView(report: sheet.report) { model.reportSheet = nil }
        }
        .alert(model.message?.title ?? "", isPresented: Binding(
            get: { model.message != nil }, set: { if !$0 { model.message = nil } })
        ) {
            Button("OK") { model.message = nil }
        } message: {
            Text(model.message?.text ?? "")
        }
        .confirmationDialog(
            "Remove “\(model.workPendingRemoval?.title ?? "")” from the library?",
            isPresented: Binding(get: { model.workPendingRemoval != nil }, set: { if !$0 { model.workPendingRemoval = nil } }),
            presenting: model.workPendingRemoval
        ) { work in
            Button("Remove", role: .destructive) { model.remove(work) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its copy and its first-page copy are deleted from the library folder. Your original file is not touched.")
        }
    }

    private var subtitle: String {
        let count = model.hits.count
        let fanfics = count == 1 ? "1 fanfic" : "\(count) fanfics"
        if let fandom = model.selectedFandomName { return "\(fandom) · \(fanfics)" }
        return fanfics
    }
}

/// Shown while files are dragged over the window (ui-spec U11).
struct DropHighlight: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .overlay {
                Text("Drop PDFs or EPUBs to add them")
                    .font(.title3.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
            }
            .padding(8)
            .allowsHitTesting(false)
    }
}
