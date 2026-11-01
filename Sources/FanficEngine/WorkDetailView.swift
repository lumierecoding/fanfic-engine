import FanficCore
import SwiftUI

/// Right column: buttons, the first-page copy, and the work's details with both IDs (ui-spec U7, U8).
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
                    FirstPagePreview(url: model.library.url(of: work.firstPageFile), id: work.firstPageID)
                    details(work)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            ContentUnavailableView("Select a fanfic", systemImage: "doc.text.magnifyingglass")
        }
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
