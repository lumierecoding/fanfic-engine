import AppKit
import SwiftUI

/// The band behind the window title and toolbar over the works list and details columns (ui-spec U22–U24, U33).
///
/// On macOS 27.2 the system's own band and its bottom line start 2 pt left of the sidebar divider, so the lines
/// don't meet (a bare three-column `NavigationSplitView` shows the same step). The app therefore hides the system
/// band (`toolbarBackgroundVisibility(.hidden, for: .windowToolbar)`) and draws the same title-bar material itself,
/// from the window top to the toolbar's bottom edge, with macOS's bottom line.
///
/// The band is drawn once over the whole split view, from the works list's left edge (the sidebar divider) to the
/// window's right edge. Drawn per column, the divider between the works list and the details column ran up through
/// the toolbar buttons (ui-spec change 6), because macOS draws that divider above the columns. Where the works list
/// starts and where the toolbar ends are measured in the works list column.
///
/// Only on macOS 27 and later, where the step was seen; earlier systems keep their own band.
struct TitleBandMetrics: Equatable {
    /// The works list's left edge (= the sidebar divider's right edge), in window coordinates.
    var leadingX: CGFloat = 0
    /// The toolbar's bottom edge, in window coordinates.
    var bottomY: CGFloat = 0
}

private struct TitleBand: ViewModifier {
    let metrics: TitleBandMetrics

    func body(content: Content) -> some View {
        content.overlay(alignment: .topLeading) {
            GeometryReader { geometry in
                let frame = geometry.frame(in: .global)
                let x = max(0, metrics.leadingX - frame.minX)
                VStack(spacing: 0) {
                    TitlebarMaterial().frame(height: max(0, metrics.bottomY - frame.minY))
                    BandLine()
                }
                .frame(width: max(0, frame.width - x))
                .offset(x: x)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .opacity(metrics.bottomY > 0 ? 1 : 0)
        }
    }
}

/// Whether the app draws its own title band (macOS 27 and later).
private var drawsOwnTitleBand: Bool {
    if #available(macOS 27, *) { true } else { false }
}

extension View {
    /// The app-drawn title band over the works list and details columns, on the split view.
    @ViewBuilder func titleBand(_ metrics: TitleBandMetrics) -> some View {
        if drawsOwnTitleBand { modifier(TitleBand(metrics: metrics)) } else { self }
    }

    /// On the works list and details columns: fill the column (empty states are only as tall as their text) and
    /// report the column's frame, from which the works list gives the band's left edge and bottom.
    @ViewBuilder func titleBandColumn(reporting report: @escaping (CGRect) -> Void = { _ in }) -> some View {
        if drawsOwnTitleBand {
            frame(maxWidth: .infinity, maxHeight: .infinity)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { report($0) }
        } else {
            self
        }
    }

    /// Hides the system's title band where the app draws its own.
    @ViewBuilder func hidingSystemTitleBand() -> some View {
        if drawsOwnTitleBand { toolbarBackgroundVisibility(.hidden, for: .windowToolbar) } else { self }
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
