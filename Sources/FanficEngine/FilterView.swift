import FanficCore
import SwiftUI

/// The choices of the Filter page, above its result list (ui-spec change 12, U62–U65, U67): up to 5 tags that must
/// all be present, and pairings, fandoms, characters and tags to leave out (SPEC section 6, Filter). Drawn in Liquid
/// Glass on macOS 26 and later (the owner's request), in a frosted material before.
struct FilterChoicesView: View {
    @Bindable var model: AppModel
    @AppStorage("includeFriendships") private var includeFriendships = true

    /// A row of the page: the tags that must be present, or one of the four "leave out" lists.
    enum Row: Hashable {
        case tags
        case leaveOut(WorkFilter.Kind)
    }

    /// What is typed in each row's Add field. Developer option `-filterTyping "<row>:<text>"` (row `tags`, or
    /// `pairing`, `fandom`, `character`, `tag` for the leave-out rows) prefills one, for pictures of the suggestions.
    @State private var typing: [Row: String] = Self.typingOnLaunch
    @FocusState private var focused: Row?
    /// Lets a new capsule flow out of its row's Add field, and a removed one melt back.
    @Namespace private var glassSpace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Heading line: the count of tags and Clear Filter on the right, so they take no line of their own.
                HStack(spacing: 8) {
                    Label("With all of these tags", systemImage: "tag")
                        .font(.headline)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Text("\(model.filter.tags.count) of \(WorkFilter.maxTags)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())  // the number rolls (ui-spec U78)
                    Spacer(minLength: 8)
                    // In a narrow column only the symbol, so the heading stays on one line.
                    ViewThatFits(in: .horizontal) {
                        clearButton(iconOnly: false)
                        clearButton(iconOnly: true)
                    }
                }
                rowContent(.tags)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label("Leave out", systemImage: "minus.circle")
                    .font(.headline)
                // Labels right-aligned in one column (U64); a fixed width keeps the wrapping rows' widths known.
                ForEach(WorkFilter.Kind.allCases) { kind in
                    HStack(alignment: .top, spacing: 10) {
                        Text(Self.label(kind))
                            .foregroundStyle(.secondary)
                            .frame(width: 76, alignment: .trailing)
                            .padding(.top, 5)
                        rowContent(.leaveOut(kind))
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .task {
            // Developer option `-focusFilter <row>` (same row names as `-filterTyping`): puts the keyboard in that Add
            // field at start, for trying Return and Escape in a test copy.
            guard let row = Self.row(named: UserDefaults.standard.string(forKey: "focusFilter") ?? "") else { return }
            try? await Task.sleep(for: .milliseconds(600))
            focused = row
        }
    }

    private func clearButton(iconOnly: Bool) -> some View {
        Button {
            withAnimation(Motion.move(reduceMotion)) { model.filter.clear() }
            typing = [:]
        } label: {
            if iconOnly {
                Label("Clear Filter", systemImage: "xmark.circle").labelStyle(.iconOnly)
            } else {
                Label("Clear Filter", systemImage: "xmark.circle")
            }
        }
        .controlSize(.small)
        .glassButton()
        .fixedSize()
        .disabled(model.filter.isEmpty)
        .help(iconOnly ? "Clear Filter: remove every tag and every left-out entry" : "Remove every tag and every left-out entry")
    }

    // MARK: One row: capsules, the Add field, suggestions

    @ViewBuilder
    private func rowContent(_ row: Row) -> some View {
        let text = typing[row] ?? ""
        VStack(alignment: .leading, spacing: 6) {
            GlassGroup(spacing: 6) {
                FlowLayout(spacing: 6) {
                    ForEach(entries(row)) { entry in
                        ChoiceCapsule(name: entry.display, leftOut: row != .tags) { remove(entry, from: row) }
                            .appGlassID(entry.key, in: glassSpace)
                    }
                    addField(row)
                        .appGlassID("field \(row)", in: glassSpace)
                }
            }
            if !NameMatcher.key(text).isEmpty {
                // Fades and grows in from its field (ui-spec U78); only fades with Reduce Motion.
                suggestionList(row, text: text)
                    .transition(Motion.reduced(reduceMotion) ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
            }
        }
        .animation(Motion.reduced(reduceMotion) ? Motion.fade(duration: 0.15) : .easeOut(duration: 0.18), value: NameMatcher.key(text).isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addField(_ row: Row) -> some View {
        let full = row == .tags && !model.filter.canAddTag
        // A glass pill with a plus symbol (ui-spec change 12, look); the field with the keyboard gets an accent outline.
        return HStack(spacing: 5) {
            Image(systemName: "plus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("", text: binding(row), prompt: Text(full ? "5 tags at most" : Self.prompt(row)))
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .disabled(full)
                .focused($focused, equals: row)
                .onSubmit { if let first = suggestions(row, text: typing[row] ?? "").first { add(first, to: row) } }
                .onKeyPress(.escape) {
                    guard !(typing[row] ?? "").isEmpty else { return .ignored }
                    typing[row] = ""
                    return .handled
                }
                .accessibilityLabel(Self.prompt(row))
        }
        .padding(.horizontal, 10)
        .frame(width: 140, height: 26)
        .appGlass(in: Capsule(), interactive: !full)
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(focused == row ? 0.9 : 0), lineWidth: 1.5))
        .opacity(full ? 0.6 : 1)
    }

    /// Up to 6 matches right under the field, inside the page (U65); the first one is what Return adds.
    private func suggestionList(_ row: Row, text: String) -> some View {
        let found = suggestions(row, text: text)
        return VStack(alignment: .leading, spacing: 2) {
            if found.isEmpty {
                Text("No \(Self.plural(row)) match “\(text.trimmingCharacters(in: .whitespaces))”")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            }
            ForEach(Array(found.enumerated()), id: \.element.entry.key) { index, item in
                SuggestionButton(name: item.entry.display, count: item.count, isFirst: index == 0) {
                    add(item, to: row)
                }
            }
        }
        .padding(4)
        .frame(maxWidth: 320, alignment: .leading)
        .appGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Data

    private struct Suggestion {
        let entry: WorkFilter.Entry
        let count: Int
    }

    private func entries(_ row: Row) -> [WorkFilter.Entry] {
        switch row {
        case .tags: model.filter.tags
        case .leaveOut(let kind): model.filter.leftOut(kind)
        }
    }

    private func suggestions(_ row: Row, text: String) -> [Suggestion] {
        let library = model.library
        let chosen: Set<String>
        let kind: WorkFilter.Kind
        switch row {
        case .tags: chosen = model.filter.chosenKeys(leftOut: nil); kind = .tag
        case .leaveOut(let k): chosen = model.filter.chosenKeys(leftOut: k); kind = k
        }
        func found<G: SidebarGroup & Identifiable>(_ groups: [G]) -> [Suggestion] where G.ID == String {
            WorkFilter.suggestions(text, in: groups, kind: kind, excluding: chosen)
                .map { Suggestion(entry: WorkFilter.Entry(key: $0.id, display: $0.display), count: $0.workIDs.count) }
        }
        switch kind {
        case .pairing: return found(library.pairingList(includeFriendships: includeFriendships))
        case .fandom: return found(library.fandomList())
        case .character: return found(library.characterList(includeFriendships: includeFriendships))
        case .tag: return found(library.tagList())
        }
    }

    private func add(_ item: Suggestion, to row: Row) {
        withAnimation(Motion.move(reduceMotion)) {
            switch row {
            case .tags: _ = model.filter.addTag(item.entry)
            case .leaveOut(let kind): _ = model.filter.leaveOut(kind, item.entry)
            }
        }
        typing[row] = ""
        focused = row == .tags && !model.filter.canAddTag ? nil : row
    }

    private func remove(_ entry: WorkFilter.Entry, from row: Row) {
        withAnimation(Motion.move(reduceMotion)) {
            switch row {
            case .tags: model.filter.removeTag(key: entry.key)
            case .leaveOut(let kind): model.filter.removeLeftOut(kind, key: entry.key)
            }
        }
    }

    private func binding(_ row: Row) -> Binding<String> {
        Binding(get: { typing[row] ?? "" }, set: { typing[row] = $0 })
    }

    // MARK: Words

    private static func label(_ kind: WorkFilter.Kind) -> String {
        switch kind {
        case .pairing: "Pairings"
        case .fandom: "Fandoms"
        case .character: "Characters"
        case .tag: "Tags"
        }
    }

    private static func prompt(_ row: Row) -> String {
        switch row {
        case .tags, .leaveOut(.tag): "Add tag…"
        case .leaveOut(.pairing): "Add pairing…"
        case .leaveOut(.fandom): "Add fandom…"
        case .leaveOut(.character): "Add character…"
        }
    }

    private static func plural(_ row: Row) -> String {
        switch row {
        case .tags, .leaveOut(.tag): "tags"
        case .leaveOut(.pairing): "pairings"
        case .leaveOut(.fandom): "fandoms"
        case .leaveOut(.character): "characters"
        }
    }

    private static var typingOnLaunch: [Row: String] {
        guard let value = UserDefaults.standard.string(forKey: "filterTyping"), let colon = value.firstIndex(of: ":") else { return [:] }
        let text = String(value[value.index(after: colon)...])
        return row(named: String(value[..<colon])).map { [$0: text] } ?? [:]
    }

    /// `tags`, or `pairing`, `fandom`, `character`, `tag` for the leave-out rows (developer options).
    private static func row(named name: String) -> Row? {
        name == "tags" ? .tags : WorkFilter.Kind(rawValue: name).map { .leaveOut($0) }
    }
}

/// One chosen entry (U63, U64): a glass pill, accent-tinted with a tag symbol for a tag that must be present, clear
/// with a red minus symbol for a left-out entry; the name, and a button that removes it.
private struct ChoiceCapsule: View {
    let name: String
    let leftOut: Bool
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: leftOut ? "minus.circle.fill" : "tag.fill")
                .foregroundStyle(leftOut ? AnyShapeStyle(Color.red.opacity(0.85)) : AnyShapeStyle(Color.accentColor))
                .accessibilityHidden(true)
            // Shortened in the middle when the column is too narrow for the whole name.
            Text(name)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 220, alignment: .leading)
            Button(action: remove) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .padding(3)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Remove \(name)")
            .accessibilityLabel("Remove \(name)")
        }
        .font(.callout)
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .frame(height: 26)
        .appGlass(in: Capsule(), tint: leftOut ? nil : Color.accentColor.opacity(0.28), interactive: true)
        .help(name)
    }
}

/// A suggestion under an Add field: name and number of fanfics; the first one (what Return adds) is shaded.
private struct SuggestionButton: View {
    let name: String
    let count: Int
    let isFirst: Bool
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(name)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text("\(count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(hovered || isFirst ? AnyShapeStyle(Color.accentColor.opacity(hovered ? 0.28 : 0.18)) : AnyShapeStyle(.clear),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
        .accessibilityLabel("\(name), \(count) fanfics")
    }
}

/// Lays its views out left to right and starts a new line when the next one doesn't fit (the capsules, U63).
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available = proposal.width ?? .infinity
        let rows = arrange(width: available, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(0, rows.count - 1))
        return CGSize(width: available.isFinite ? available : width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                // Vertically centred in the row, so a 22 pt capsule and a text field line up.
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            size.width = min(size.width, width)
            let needed = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if needed > width, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
            current.sizes.append(size)
        }
        if !current.indices.isEmpty { rows.append(current) }
        return rows
    }
}
