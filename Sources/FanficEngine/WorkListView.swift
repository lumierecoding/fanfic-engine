import AppKit
import FanficCore
import SwiftUI

/// Middle column: the works that match the search, sorted by title (ui-spec U5, U6, U10).
struct WorkListView: View {
    @Bindable var model: AppModel
    /// Developer option `-focusList YES` (screenshots of a selected row with the list focused).
    @FocusState private var listFocused: Bool

    var body: some View {
        let hits = model.hits
        Group {
            if model.library.works.isEmpty {
                ContentUnavailableView {
                    Label("No fanfics yet", systemImage: "books.vertical")
                } description: {
                    Text("Drop EPUB or PDF files here, or click Add Files…")
                }
            } else if hits.isEmpty {
                if model.sidebarSelection == .noPairing {
                    ContentUnavailableView("Every fanfic has a pairing", systemImage: "checkmark.circle")
                } else {
                    ContentUnavailableView("No fanfics found for “\(model.searchText)”", systemImage: "magnifyingglass")
                }
            } else {
                List(hits, selection: $model.selectedWorkID) { hit in
                    WorkRow(hit: hit, isSelected: model.selectedWorkID == hit.id)
                        .contextMenu {
                            Button("Open Fanfic") { model.open(hit.work) }
                            Button("Open First Page") { model.openFirstPage(hit.work) }
                            Button("Show in Finder") { model.showInFinder(hit.work) }
                            Divider()
                            Button("Remove from Library…", role: .destructive) { model.confirmRemoval(of: hit.work) }
                        }
                }
                .background(OverlayScroller())  // no scroll bar strip with a mouse (ui-spec change 10)
                .focused($listFocused)
                .onAppear {
                    guard UserDefaults.standard.bool(forKey: "focusList") else { return }
                    NSApp.activate()  // a selected row is only drawn emphasized in the active window
                    listFocused = true
                }
            }
        }
    }
}

struct WorkRow: View {
    let hit: SearchHit
    /// Passed in: on macOS 27 `backgroundProminence` stays `.standard` in this list even for the selected row, so the
    /// matches were drawn blue on the blue selection (found with change 11; U6 says bold, not accent, when selected).
    var isSelected = false
    /// `.increased` while the row is selected; matching tags are then bold instead of accent-coloured.
    @Environment(\.backgroundProminence) private var prominence

    var body: some View {
        let work = hit.work
        VStack(alignment: .leading, spacing: 3) {
            Text(work.title)
                .font(.body.weight(.semibold))
                .lineLimit(2)
            Text(([work.kind.label, work.author] + [work.fandoms.isEmpty ? nil : work.fandoms.joined(separator: ", ")])
                    .compactMap { $0 }.joined(separator: " · "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            if work.relationships.isEmpty {
                Text("No pairing found")
                    .font(.callout)
                    .italic()
                    .foregroundStyle(.secondary)
            } else {
                Text(relationshipsText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // Found by a tag: the matching tags, in page order (ui-spec U57).
            if !hit.matchedTags.isEmpty {
                let tags = work.tags.filter(hit.matchedTags.contains).joined(separator: ", ")
                Text("\(Image(systemName: "tag")) \(tags)")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isSelected || prominence == .increased ? AnyShapeStyle(.primary) : AnyShapeStyle(Color.accentColor))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Matching tags: \(tags)")
            }
        }
        .padding(.vertical, 6)
    }

    private var relationshipsText: AttributedString {
        let selected = isSelected || prominence == .increased
        var text = AttributedString()
        for (index, tag) in hit.work.relationships.enumerated() {
            if index > 0 { text += AttributedString(", ") }
            var part = AttributedString(tag)
            if hit.matched.contains(tag) {
                part.font = .callout.weight(.semibold)
                if !selected { part.foregroundColor = .accentColor }
            }
            text += part
        }
        return text
    }
}
