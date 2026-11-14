import AppKit
import SwiftUI

/// Gives a column the thin scroll bar that floats over it and shows while scrolling, whatever the system setting:
/// the sidebar (ui-spec change 9, U47–U49), the works list and the details column (change 10, U50–U52).
///
/// With a mouse connected (*Show scroll bars: Automatically*) or *Always*, macOS gives every scrolling area a
/// permanent scroll bar in a track of its own: a grey strip with a line at the column's right edge. SwiftUI has no
/// setting for the scroll bar style, so this goes behind a `List` or `ScrollView` (`.background(OverlayScroller())`),
/// finds the `NSScrollView` in the same place and sets its style to `.overlay`. macOS sets every scroll view back to the system style when that changes (a mouse plugged in
/// or out), so the style is set again after each change.
struct OverlayScroller: NSViewRepresentable {
    func makeNSView(context: Context) -> ScrollViewFinder { ScrollViewFinder() }
    func updateNSView(_ view: ScrollViewFinder, context: Context) { view.applySoon() }

    /// An empty view behind the list or scroll view; it finds the scroll view that covers the same place in the window.
    final class ScrollViewFinder: NSView {
        private weak var scrollView: NSScrollView?
        private var observer: NSObjectProtocol?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observer { NotificationCenter.default.removeObserver(observer) }
            observer = nil
            guard window != nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: NSScroller.preferredScrollerStyleDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                // After AppKit has set every scroll view to the new system style.
                MainActor.assumeIsolated { self?.applySoon() }
            }
            applySoon()
        }

        override func layout() {
            super.layout()
            applySoon()
        }

        /// On the next turn of the run loop, when SwiftUI has put the list's scroll view in place.
        func applySoon() {
            DispatchQueue.main.async { [weak self] in self?.apply() }
        }

        private func apply() {
            if scrollView?.window == nil { scrollView = findScrollView() }
            guard let scrollView, scrollView.scrollerStyle != .overlay else { return }
            scrollView.scrollerStyle = .overlay
        }

        /// The scroll view behind this view (the list's): it ends at the same right edge and covers this view's middle.
        /// With the Liquid Glass design scroll views reach under the floating sidebar and the toolbar, so their left
        /// edge and height no longer match the visible column (ui-spec change 13); when several fit (the Filter page's
        /// choices above its result list), the smallest wins.
        private func findScrollView() -> NSScrollView? {
            guard let root = window?.contentView, bounds.width > 0 else { return nil }
            let mine = convert(bounds, to: nil)
            let middle = CGPoint(x: mine.midX, y: mine.midY)
            var best: (scroll: NSScrollView, area: CGFloat)?
            func search(_ view: NSView) {
                if let scroll = view as? NSScrollView {
                    let frame = scroll.convert(scroll.bounds, to: nil)
                    if abs(frame.maxX - mine.maxX) <= 2, frame.minX <= mine.minX + 2, frame.contains(middle) {
                        let area = frame.width * frame.height
                        if best == nil || area < best!.area { best = (scroll, area) }
                    }
                }
                for subview in view.subviews { search(subview) }
            }
            search(root)
            return best?.scroll
        }
    }
}
