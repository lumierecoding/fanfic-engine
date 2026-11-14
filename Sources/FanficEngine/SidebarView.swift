import FanficCore
import SwiftUI

/// Left column (ui-spec U2, U3, U12, U13, U53, U61): All Works, No Pairing Found and Filter, then Fandoms, Characters, Pairings
/// and Tags.
/// The three lists start folded; their open/closed state and the Settings choices are kept in the app's preferences.
struct SidebarView: View {
    @Bindable var model: AppModel

    @AppStorage("showFandoms") private var showFandoms = true
    @AppStorage("showCharacters") private var showCharacters = true
    @AppStorage("showPairings") private var showPairings = true
    @AppStorage("showTags") private var showTags = true
    @AppStorage("sidebarSort") private var sort = SidebarSort.name
    @AppStorage("includeFriendships") private var includeFriendships = true
    @AppStorage("fandomsExpanded") private var fandomsExpanded = false
    @AppStorage("charactersExpanded") private var charactersExpanded = false
    @AppStorage("pairingsExpanded") private var pairingsExpanded = false
    @AppStorage("tagsExpanded") private var tagsExpanded = false
    /// The Search tags field of the open Tags list (ui-spec U54); only filters the list.
    @State private var tagFilter = UserDefaults.standard.string(forKey: "tagFilter") ?? ""  // developer option for screenshots

    var body: some View {
        let works = model.library.works
        List(selection: $model.sidebarSelection) {
            Section {
                Label("All Works", systemImage: "books.vertical")
                    .badge(works.count)
                    .glassListRowBackground(selected: model.sidebarSelection == .all, horizontalInset: Self.pillInset, verticalInset: Self.pillGap)
                    .tag(SidebarItem.all)
                Label("No Pairing Found", systemImage: "questionmark.circle")
                    .badge(model.library.worksWithoutPairing.count)
                    .glassListRowBackground(selected: model.sidebarSelection == .noPairing, horizontalInset: Self.pillInset, verticalInset: Self.pillGap)
                    .tag(SidebarItem.noPairing)
                // The Filter page (ui-spec change 12, U61): up to 5 tags at once and entries to leave out.
                // A text badge, because macOS leaves out a number badge of 0, and "0" matters here (round 2).
                Label("Filter", systemImage: "line.3.horizontal.decrease.circle")
                    .badge(Text(model.filterCount(includeFriendships: includeFriendships), format: .number))
                    .glassListRowBackground(selected: model.sidebarSelection == .filter, horizontalInset: Self.pillInset, verticalInset: Self.pillGap)
                    .tag(SidebarItem.filter)
            }
            if showFandoms {
                Section(isExpanded: $fandomsExpanded) {
                    ForEach(model.library.fandomList(sort: sort)) { group in
                        row(group.display, count: group.workIDs.count, item: .fandom(group.key))
                    }
                } header: {
                    SectionHeader(title: "Fandoms", isExpanded: $fandomsExpanded)
                }
            }
            if showCharacters {
                Section(isExpanded: $charactersExpanded) {
                    ForEach(model.library.characterList(includeFriendships: includeFriendships, sort: sort)) { group in
                        row(group.display, count: group.workIDs.count, item: .character(group.key))
                    }
                } header: {
                    SectionHeader(title: "Characters", isExpanded: $charactersExpanded)
                }
            }
            if showPairings {
                Section(isExpanded: $pairingsExpanded) {
                    ForEach(model.library.pairingList(includeFriendships: includeFriendships, sort: sort)) { group in
                        row(group.display, count: group.workIDs.count, item: .pairing(group.key))
                    }
                } header: {
                    SectionHeader(title: "Pairings", isExpanded: $pairingsExpanded)
                }
            }
            // The Additional Tags (SPEC section 5b, ui-spec U53): a filter, like a fandom.
            if showTags {
                Section(isExpanded: $tagsExpanded) {
                    tagSearchField
                    let tags = model.library.tagList(sort: sort).matching(tagFilter)
                    if tags.isEmpty, !tagFilter.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("No tags match “\(tagFilter)”")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(tags) { group in
                        row(group.display, count: group.workIDs.count, item: .tag(group.key))
                    }
                } header: {
                    SectionHeader(title: "Tags", isExpanded: $tagsExpanded)
                }
            }
        }
        .listStyle(.sidebar)
        .auraListBackground()  // the window's aura behind the sidebar (ui-spec change 16)
        .background(OverlayScroller())  // no scroll bar strip beside the counts with a mouse (ui-spec change 9)
    }

    /// First row of the open Tags list (ui-spec U54): narrows the list by the word-start rule.
    private var tagSearchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search tags", text: $tagFilter)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
            if !tagFilter.isEmpty {
                Button { tagFilter = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear")
            }
        }
        // A glass pill like the Filter page's fields (ui-spec change 14).
        .padding(.horizontal, 10)
        .frame(height: 26)
        .appGlass(in: Capsule(), interactive: true)
        .padding(.vertical, 2)
    }

    /// Every row on a glass pill as wide and round as the selection (ui-spec change 15).
    private func row(_ name: String, count: Int, item: SidebarItem) -> some View {
        Text(name)
            .lineLimit(2)
            .help(name)
            .badge(count)
            .glassListRowBackground(selected: model.sidebarSelection == item, horizontalInset: Self.pillInset, verticalInset: Self.pillGap)
            .tag(item)
    }

    /// The row's glass pill inside the whole row: 10 pt in from the sidebar's sides, like the selection, and 2 pt in from
    /// the row's top and bottom, so every two pills are 4 pt apart, one-line or two-line (measured in captures).
    private static let pillInset: CGFloat = 10
    private static let pillGap: CGFloat = 2
}


/// A sidebar section name that opens or folds its section when clicked (ui-spec U21),
/// in addition to the arrow macOS shows on hover. Looks like a normal section header.
struct SectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(Motion.move(reduceMotion, duration: 0.25)) { isExpanded.toggle() }  // ui-spec U77
            }
            .help(isExpanded ? "Click to fold \(title)" : "Click to open \(title)")
            .accessibilityAddTraits(.isButton)
    }
}
