import AppKit
import FanficCore
import SwiftUI

/// Middle column: the works that match the search, sorted by title (ui-spec U5, U6, U10); with Filter selected, the
/// filter's choices above them (ui-spec change 12).
struct WorkListView: View {
    @Bindable var model: AppModel
    /// Developer option `-focusList YES` (screenshots of a selected row with the list focused).
    @FocusState private var listFocused: Bool
    /// Read so the Filter page's result follows Settings → friendship tags at once (characters left out, U64).
    @AppStorage("includeFriendships") private var includeFriendships = true
    /// The filter choices' own height, so they take no more than they need (and at most half the column, U69).
    @State private var choicesHeight: CGFloat = 0

    var body: some View {
        let _ = includeFriendships
        let hits = model.hits
        // A new sidebar selection cross-fades the column; typing a search changes no selection, so the list updates
        // at once without animation (ui-spec change 13, U76).
        ZStack {
            Group {
                if model.library.works.isEmpty {
                    ContentUnavailableView {
                        Label("No fanfics yet", systemImage: "books.vertical")
                    } description: {
                        Text("Drop EPUB or PDF files here, or click Add Files…")
                    }
                    .glassEmptyState()
                } else if model.sidebarSelection == .filter {
                    filterPage(hits)
                } else if hits.isEmpty {
                    if model.sidebarSelection == .noPairing {
                        ContentUnavailableView("Every fanfic has a pairing", systemImage: "checkmark.circle")
                            .glassEmptyState()
                    } else {
                        ContentUnavailableView("No fanfics found for “\(model.searchText)”", systemImage: "magnifyingglass")
                            .glassEmptyState()
                    }
                } else {
                    results(hits)
                }
            }
            .id(model.sidebarSelection)
            .transition(.opacity)
        }
        .animation(Motion.fade(duration: 0.18), value: model.sidebarSelection)
    }

    /// The Filter page (U62, U66, U69): the choices, a divider, the result list. The choices stay visible when
    /// nothing matches, and scroll inside when they need more than half the column.
    private func filterPage(_ hits: [SearchHit]) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    // The choices on a glass panel (ui-spec change 15).
                    FilterChoicesView(model: model)
                        .appGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { choicesHeight = $0 }
                }
                .scrollBounceBehavior(.basedOnSize)
                .background(OverlayScroller())
                .hardTopScrollEdge()
                .frame(height: min(max(choicesHeight, 1), geometry.size.height * 0.5))
                Divider()
                if hits.isEmpty {
                    let search = model.searchText.trimmingCharacters(in: .whitespaces)
                    ContentUnavailableView(search.isEmpty ? "No fanfics match this filter" : "No fanfics found for “\(search)” in this filter",
                                           systemImage: "line.3.horizontal.decrease.circle")
                        .glassEmptyState()
                } else {
                    results(hits)
                }
            }
        }
    }

    private func results(_ hits: [SearchHit]) -> some View {
        List(hits, selection: $model.selectedWorkID) { hit in
            let selected = model.selectedWorkID == hit.id
            // Each fanfic on its own glass card (ui-spec change 14); the selected one keeps the system's selection.
            WorkRow(hit: hit, isSelected: selected)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    // As wide and as round as the system's selection, so a selected card and the others line up.
                    if !selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.clear)
                            .appGlass(in: RoundedRectangle(cornerRadius: 10, style: .continuous), interactive: true)
                            .padding(.horizontal, -12)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 6, bottom: 3, trailing: 6))
                .contextMenu {
                    Button("Open Fanfic") { model.open(hit.work) }
                    Button("Open First Page") { model.openFirstPage(hit.work) }
                    Button("Show in Finder") { model.showInFinder(hit.work) }
                    Divider()
                    Button("Remove from Library…", role: .destructive) { model.confirmRemoval(of: hit.work) }
                }
        }
        .auraListBackground()  // the window's aura shows between the cards (ui-spec change 16)
        .background(OverlayScroller())  // no scroll bar strip with a mouse (ui-spec change 10)
        .hardTopScrollEdge()
        .focused($listFocused)
        .onAppear {
            guard UserDefaults.standard.bool(forKey: "focusList") else { return }
            NSApp.activate()  // a selected row is only drawn emphasized in the active window
            listFocused = true
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
            // Found by a tag, or chosen on the Filter page: those tags, in page order (ui-spec U57, U66).
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
