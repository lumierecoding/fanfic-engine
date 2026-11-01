import FanficCore
import SwiftUI

/// Middle column: the works that match the search, sorted by title (ui-spec U5, U6, U10).
struct WorkListView: View {
    @Bindable var model: AppModel

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
                    WorkRow(hit: hit)
                        .contextMenu {
                            Button("Open Fanfic") { model.open(hit.work) }
                            Button("Open First Page") { model.openFirstPage(hit.work) }
                            Button("Show in Finder") { model.showInFinder(hit.work) }
                            Divider()
                            Button("Remove from Library…", role: .destructive) { model.confirmRemoval(of: hit.work) }
                        }
                }
            }
        }
    }
}

struct WorkRow: View {
    let hit: SearchHit
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
        }
        .padding(.vertical, 6)
    }

    private var relationshipsText: AttributedString {
        let selected = prominence == .increased
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
