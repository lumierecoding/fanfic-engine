import FanficCore
import SwiftUI

/// Sheet after an import: counts and file names per result, each result group on a glass panel (ui-spec change 15).
struct ImportSummaryView: View {
    let report: ImportReport
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(report.addedCount == 1 ? "1 fanfic added" : "\(report.addedCount) fanfics added")
                .font(.title2.weight(.semibold))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ImportReport.Outcome.allCases, id: \.self) { outcome in
                        let items = report.items(outcome)
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(outcome.heading) (\(items.count))")
                                    .font(.headline)
                                ForEach(items) { item in
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(item.fileName)
                                        if let detail = item.detail {
                                            Text(outcome == .duplicate ? "same file as “\(detail)”" : detail)
                                                .font(.callout)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .glassPanel(padding: 10, cornerRadius: 12)
                        }
                    }
                }
                // Room for the panels' glass edges, which the scroll view would otherwise cut off.
                .padding(.vertical, 6)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 380)
            HStack {
                Spacer()
                Button("OK", action: done)
                    .keyboardShortcut(.defaultAction)
                    .glassButton(prominent: true)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
