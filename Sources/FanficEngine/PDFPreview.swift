import AppKit
import PDFKit
import SwiftUI

/// The first-page copy as a picture of the whole page, as wide as the column (ui-spec U7).
/// A picture instead of a PDFView, so scrolling the details column is never caught by an inner scroll view.
struct FirstPagePreview: View {
    let url: URL
    let id: UUID
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))
                    .accessibilityLabel("First page")
                    .transition(.opacity)  // fades in when it is ready (ui-spec U75)
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.quaternary)
                    .aspectRatio(595.0 / 842.0, contentMode: .fit)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .animation(Motion.fade(duration: 0.2), value: image != nil)
        .task(id: id) {
            let url = url
            image = await Task.detached(priority: .userInitiated) { Self.render(url) }.value
        }
    }

    private nonisolated static func render(_ url: URL) -> NSImage? {
        guard let page = PDFDocument(url: url)?.page(at: 0) else { return nil }
        let bounds = page.bounds(for: .mediaBox)
        let scale = 1600 / max(bounds.width, bounds.height)
        return page.thumbnail(of: CGSize(width: bounds.width * scale, height: bounds.height * scale), for: .mediaBox)
    }
}
