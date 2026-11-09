import FanficCore
import SwiftUI

/// Left column (ui-spec U2, U3, U12, U13, U53): All Works and No Pairing Found, then Fandoms, Characters, Pairings
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
                    .tag(SidebarItem.all)
                Label("No Pairing Found", systemImage: "questionmark.circle")
                    .badge(model.library.worksWithoutPairing.count)
                    .tag(SidebarItem.noPairing)
            }
            if showFandoms {
                Section(isExpanded: $fandomsExpanded) {
                    ForEach(model.library.fandomList(sort: sort)) { group in
                        row(group.display, count: group.workIDs.count).tag(SidebarItem.fandom(group.key))
                    }
                } header: {
                    SectionHeader(title: "Fandoms", isExpanded: $fandomsExpanded)
                }
            }
            if showCharacters {
                Section(isExpanded: $charactersExpanded) {
                    ForEach(model.library.characterList(includeFriendships: includeFriendships, sort: sort)) { group in
                        row(group.display, count: group.workIDs.count).tag(SidebarItem.character(group.key))
                    }
                } header: {
                    SectionHeader(title: "Characters", isExpanded: $charactersExpanded)
                }
            }
            if showPairings {
                Section(isExpanded: $pairingsExpanded) {
                    ForEach(model.library.pairingList(includeFriendships: includeFriendships, sort: sort)) { group in
                        row(group.display, count: group.workIDs.count).tag(SidebarItem.pairing(group.key))
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
                        row(group.display, count: group.workIDs.count).tag(SidebarItem.tag(group.key))
                    }
                } header: {
                    SectionHeader(title: "Tags", isExpanded: $tagsExpanded)
                }
            }
        }
        .listStyle(.sidebar)
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
        .padding(.vertical, 2)
    }

    private func row(_ name: String, count: Int) -> some View {
        Text(name)
            .lineLimit(2)
            .help(name)
            .badge(count)
    }
}


/// A sidebar section name that opens or folds its section when clicked (ui-spec U21),
/// in addition to the arrow macOS shows on hover. Looks like a normal section header.
struct SectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Text(title)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation { isExpanded.toggle() }
            }
            .help(isExpanded ? "Click to fold \(title)" : "Click to open \(title)")
            .accessibilityAddTraits(.isButton)
    }
}
