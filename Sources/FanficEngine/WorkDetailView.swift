import FanficCore
import SwiftUI

/// Right column: buttons, the summary, the first-page copy, and the work's details with both IDs
/// (ui-spec U7, U8; summary: change 7, U35–U40).
struct WorkDetailView: View {
    @Bindable var model: AppModel

    var body: some View {
        if let work = model.selectedWork {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(work.title)
                            .font(.title2.weight(.semibold))
                            .textSelection(.enabled)
                        if let author = work.author {
                            Text("by \(author)")
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Button("Open Fanfic") { model.open(work) }
                        Button("Open First Page") { model.openFirstPage(work) }
                        Button("Show in Finder") { model.showInFinder(work) }
                    }
                    summary(work)
                    FirstPagePreview(url: model.library.url(of: work.firstPageFile), id: work.firstPageID)
                    details(work)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(OverlayScroller())  // no scroll bar strip with a mouse (ui-spec change 10)
        } else {
            ContentUnavailableView("Select a fanfic", systemImage: "doc.text.magnifyingglass")
        }
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
