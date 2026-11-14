import SwiftUI

/// The app's own Liquid Glass on controls (ui-spec changes 12 and 13). The system draws the rest (sidebar, toolbar,
/// search field, sheets, Settings) because the app carries the real SDK version (U70). macOS 26 and later draw glass;
/// macOS 15 gets the same shapes in a frosted material and bordered buttons. Developer option `-noGlass YES` shows
/// those macOS 15 shapes on a newer Mac (U80; the system's own parts keep their glass).
enum AppGlass {
    static let off = UserDefaults.standard.bool(forKey: "noGlass")
}

/// The app's animations (ui-spec change 13): short and without bounce. Fades stay with *Reduce Motion*; anything that
/// moves, grows or flows is left out then (U79).
enum Motion {
    /// Developer option `-reduceMotion YES`: the app's own animations behave as with *Reduce Motion* on, without
    /// changing the system setting (to check U79 in a test copy; the system's own animations follow the real setting).
    static let forcedReduce = UserDefaults.standard.bool(forKey: "reduceMotion")

    /// Whether movement is left out: the system's Reduce Motion, or the developer option.
    static func reduced(_ reduceMotion: Bool) -> Bool { reduceMotion || forcedReduce }

    /// For movement: capsules flowing, panels growing, lists opening. None with Reduce Motion.
    static func move(_ reduceMotion: Bool, duration: Double = 0.3) -> Animation? {
        reduced(reduceMotion) ? nil : .smooth(duration: duration)
    }

    /// For cross-fades: kept with Reduce Motion, they don't move anything.
    static func fade(duration: Double = 0.2) -> Animation {
        .easeInOut(duration: duration)
    }
}

extension View {
    /// Liquid Glass in `shape`, optionally tinted and lighting up under the pointer; the frosted material on macOS 15.
    @ViewBuilder
    func appGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *), !AppGlass.off {
            glassEffect(interactive ? Glass.regular.tint(tint).interactive() : Glass.regular.tint(tint), in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .background(tint ?? Color.clear, in: shape)
        }
    }

    /// Lets a glass shape flow into another one of its group when it appears or goes (macOS 26 and later).
    @ViewBuilder
    func appGlassID(_ id: String, in namespace: Namespace.ID) -> some View {
        if #available(macOS 26, *), !AppGlass.off { glassEffectID(id, in: namespace) } else { self }
    }

    /// A glass button (prominent: tinted with the accent colour); bordered buttons on macOS 15.
    func glassButton(prominent: Bool = false) -> some View {
        modifier(GlassButtonStyle(prominent: prominent))
    }

    /// Content on a glass panel (ui-spec change 14): the details' summary, first page and grid.
    func glassPanel(padding: CGFloat = 12, cornerRadius: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .appGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// A list row on a glass pill, except when selected (the system's selection is drawn then); used by the sidebar
    /// (ui-spec change 15). The pill is laid out in the whole row, not around the row's text: macOS gives one-line and
    /// two-line rows different padding, so pills sized from the text had uneven gaps (the owner's report, 13 November).
    /// `horizontalInset` keeps it inside the selection's edges; `verticalInset` is half the gap between two pills.
    func glassListRowBackground(selected: Bool, cornerRadius: CGFloat = 10, horizontalInset: CGFloat,
                                verticalInset: CGFloat) -> some View {
        listRowBackground(
            Group {
                if !selected {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .appGlass(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), interactive: true)
                        .padding(.horizontal, horizontalInset)
                        .padding(.vertical, verticalInset)
                }
            }
        )
    }

    /// An empty state ("Select a fanfic", "No fanfics found" …) on a glass card in the middle of its column
    /// (ui-spec change 14).
    func glassEmptyState() -> some View {
        self.frame(maxWidth: 300)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .appGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Rows scrolled up under the glass toolbar get the system's hard edge, so the window's title and subtitle stay
    /// readable over them (U71). Nothing to do on macOS 15, which has an opaque toolbar.
    @ViewBuilder
    func hardTopScrollEdge() -> some View {
        if #available(macOS 26, *) { scrollEdgeEffectStyle(.hard, for: .top) } else { self }
    }
}

/// Groups glass shapes that sit side by side, so they are drawn together and can flow into each other.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *), !AppGlass.off {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

private struct GlassButtonStyle: ViewModifier {
    let prominent: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *), !AppGlass.off {
            if prominent { content.buttonStyle(.glassProminent) } else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent) } else { content.buttonStyle(.bordered) }
        }
    }
}
