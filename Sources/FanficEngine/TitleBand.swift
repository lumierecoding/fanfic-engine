import AppKit
import SwiftUI

/// The band behind the window title and toolbar over the works list and details columns (ui-spec U22–U24).
///
/// On macOS 27 the system's own band and its bottom line start 2 pt left of the sidebar divider, so the lines
/// don't meet (a bare three-column `NavigationSplitView` shows the same step). The app therefore hides the system
/// band (`toolbarBackgroundVisibility(.hidden, for: .windowToolbar)` in `ContentView`) and each column draws the
/// same title-bar material itself, from the window top to the toolbar's bottom edge, with macOS's bottom line.
/// It starts exactly at the column's edge and covers works scrolled under it.
struct TitleBand: ViewModifier {
    func body(content: Content) -> some View {
        // Fill the column first: empty states ("No fanfics yet") are only as tall as their text.
        content.frame(maxWidth: .infinity, maxHeight: .infinity).overlay(alignment: .top) {
            GeometryReader { geometry in
                // Inside the column the toolbar is the top safe-area inset; the band is drawn above it.
                let top = geometry.safeAreaInsets.top
                VStack(spacing: 0) {
                    TitlebarMaterial().frame(height: top)
                    BandLine()
                }
                .offset(y: -top)
            }
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// The app-drawn title band on macOS 27 and later; earlier systems keep their own band.
    @ViewBuilder func titleBand() -> some View {
        if #available(macOS 27, *) { modifier(TitleBand()) } else { self }
    }

    /// Hides the system's title band where the app draws its own (macOS 27 and later).
    @ViewBuilder func hidingSystemTitleBand() -> some View {
        if #available(macOS 27, *) { toolbarBackgroundVisibility(.hidden, for: .windowToolbar) } else { self }
    }
}

/// The material macOS uses behind the title bar and toolbar (follows light/dark and the window's active state).
private struct TitlebarMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .titlebar
        view.blendingMode = .withinWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// The band's bottom line like macOS's: one strong pixel, on Retina screens followed by a faint one.
private struct BandLine: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var scale

    var body: some View {
        VStack(spacing: 0) {
            Color.black.opacity(scheme == .dark ? 1 : 0.15).frame(height: 1 / scale)
            if scale >= 2 {
                Color.black.opacity(scheme == .dark ? 0.25 : 0.055).frame(height: 1 / scale)
            }
        }
    }
}
