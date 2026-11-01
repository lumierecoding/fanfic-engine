import FanficCore
import SwiftUI

/// Left column (ui-spec U2, U3, U12, U13): All Works and No Pairing Found, then Fandoms, Characters and Pairings.
/// The three lists start folded; their open/closed state and the Settings choices are kept in the app's preferences.
struct SidebarView: View {
    @Bindable var model: AppModel

    @AppStorage("showFandoms") private var showFandoms = true
    @AppStorage("showCharacters") private var showCharacters = true
    @AppStorage("showPairings") private var showPairings = true
    @AppStorage("sidebarSort") private var sort = SidebarSort.name
    @AppStorage("includeFriendships") private var includeFriendships = true
    @AppStorage("fandomsExpanded") private var fandomsExpanded = false
    @AppStorage("charactersExpanded") private var charactersExpanded = false
    @AppStorage("pairingsExpanded") private var pairingsExpanded = false

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
        }
        .listStyle(.sidebar)
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
