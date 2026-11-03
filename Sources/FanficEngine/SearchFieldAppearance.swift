import AppKit
import SwiftUI

/// Keeps the typed text in the toolbar search field readable after the window switches between light and dark
/// (ui-spec change 6, U34).
///
/// The `.searchable` toolbar field draws its text once in the colour of the moment and does not redraw it when the
/// window's look changes: on macOS 27.0.1 the owner saw black text in a dark window, and on macOS 27.2 a window that
/// switches from dark to light while open keeps white text on the light field. Its views all report the new look;
/// only the drawn text is stale. Setting the text again makes the field draw it in the current colour, so this is
/// done when the window opens and after every light/dark change.
private struct SearchFieldRedraw: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .onAppear { redrawSearchText() }
            .onChange(of: scheme) { redrawSearchText() }
    }

    private func redrawSearchText() {
        // The toolbar and its search field are made after the window's first layout, so try again shortly after.
        for delay in [0.0, 0.3, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                for window in NSApp.windows {
                    for case let item as NSSearchToolbarItem in window.toolbar?.items ?? [] {
                        let field = item.searchField
                        // While someone types, the field editor draws the text; leave it alone.
                        guard field.currentEditor() == nil else { continue }
                        let text = field.stringValue
                        field.stringValue = ""
                        field.stringValue = text
                    }
                }
            }
        }
    }
}

extension View {
    /// Redraws the toolbar search field's text in the current light or dark colour (see `SearchFieldRedraw`).
    func searchTextFollowsAppearance() -> some View {
        modifier(SearchFieldRedraw())
    }
}
