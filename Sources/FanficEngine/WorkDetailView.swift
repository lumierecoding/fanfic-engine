import FanficCore
import SwiftUI

/// Right column: buttons, the summary, the first-page copy, and the work's details with both IDs
/// (ui-spec U7, U8; summary: change 7, U35–U40). Another fanfic cross-fades in and opens at the top (change 13, U75).
struct WorkDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            if let work = model.selectedWork {
                details(of: work)
                    .id(work.workID)
                    .transition(.opacity)
            } else {
                ContentUnavailableView("Select a fanfic", systemImage: "doc.text.magnifyingglass")
                    .glassEmptyState()
                    .transition(.opacity)
            }
        }
        .animation(Motion.fade(duration: 0.2), value: model.selectedWorkID)
    }

    private func details(of work: WorkRecord) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Title, author and buttons on their own glass panel (ui-spec change 15).
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(work.title)
                                .font(.title2.weight(.semibold))
                                .textSelection(.enabled)
                            if let author = work.author {
                                Text("by \(author)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        // One glass group; Open Fanfic is the main action (ui-spec U72). In a narrow column the buttons go
                        // onto a second line instead of being cut short (glass buttons are wider than the old ones).
                        GlassGroup(spacing: 8) {
                            FlowLayout(spacing: 8) {
                                Button("Open Fanfic") { model.open(work) }
                                    .glassButton(prominent: true)
                                    .fixedSize()
                                Button("Open First Page") { model.openFirstPage(work) }
                                    .glassButton()
                                    .fixedSize()
                                Button("Show in Finder") { model.showInFinder(work) }
                                    .glassButton()
                                    .fixedSize()
                            }
                        }
                    }
                    .glassPanel()
                    // Summary, first page and details each on a glass panel (ui-spec change 14).
                    summary(work)
                        .glassPanel()
                    FirstPagePreview(url: model.library.url(of: work.firstPageFile), id: work.firstPageID)
                        .glassPanel(padding: 10)
                    details(work)
                        .glassPanel()
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(OverlayScroller())  // no scroll bar strip with a mouse (ui-spec change 10)
            .hardTopScrollEdge()
    }

    /// "Summary" in the details labels' style, then the summary in the body font (U36), or "No summary found" (U37).
    private func summary(_ work: WorkRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Summary")
                .foregroundStyle(.secondary)
            if let summary = work.summary {
                Self.summaryText(summary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            } else {
                Text("No summary found").italic().foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The paragraphs get a small extra gap (an empty line in a tiny font), so the summary stays one text that can
    /// be selected and copied as a whole (U38); the copied text is the stored summary. The empty line's height goes in
    /// whole points: font size 5 gives 7 pt (measured), anything from about 4.3 to 4.7 gives 5 pt; 6 pt can't be had.
    static let paragraphGapFontSize: CGFloat = 5

    static func summaryText(_ summary: String) -> Text {
        var text = AttributedString()
        for (index, paragraph) in summary.components(separatedBy: "\n\n").enumerated() {
            if index > 0 {
                text += AttributedString("\n")
                var gap = AttributedString("\n")
                gap.font = .system(size: paragraphGapFontSize)
                text += gap
            }
            text += AttributedString(paragraph)
        }
        return Text(text)
    }

    private func details(_ work: WorkRecord) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
            GridRow {
                label(work.fandoms.count > 1 ? "Fandoms" : "Fandom")
                if work.fandoms.isEmpty {
                    Text("No fandom found").italic().foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(work.fandoms, id: \.self) { Text($0) }
                    }
                    .textSelection(.enabled)
                }
            }
            GridRow {
                label("Relationships")
                if work.relationships.isEmpty {
                    Text("No pairing found").italic().foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(work.relationships, id: \.self) { Text($0) }
                    }
                    .textSelection(.enabled)
                }
            }
            // One wrapping line: a fic can have twenty or more tags (ui-spec U58).
            GridRow {
                label("Tags")
                if work.tags.isEmpty {
                    Text("No tags found").italic().foregroundStyle(.secondary)
                } else {
                    Text(work.tags.joined(separator: ", "))
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
            GridRow {
                label("File")
                Text(work.originalFileName).textSelection(.enabled)
            }
            GridRow {
                label("First page")
                Text(work.firstPageSource).textSelection(.enabled)
            }
            GridRow {
                label("Work ID")
                Text(work.workID.uuidString)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
            GridRow {
                label("First-page ID")
                Text(work.firstPageID.uuidString)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .gridColumnAlignment(.trailing)
    }
}
