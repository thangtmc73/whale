import SwiftUI
import Darwin

/// A hand-rolled list (not `List`/`.sidebar` style) so every color is under our control — the
/// system sidebar material fights a custom dark palette (it stays vibrant/translucent regardless
/// of background color), which doesn't fit the calm, flat "Linear/Raycast" look the brief wants.
///
/// A segmented toggle at the top switches the column between the session list and a compact file
/// tree of the project; tree rows are draggable as file URLs straight into the composer.
struct SessionSidebarView: View {
    let appViewModel: AppViewModel

    private enum Tab: String, CaseIterable { case sessions = "Sessions", files = "Files" }
    @State private var tab: Tab = .sessions

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.top, WhaleTheme.Spacing.md)
            .padding(.bottom, WhaleTheme.Spacing.sm)

            switch tab {
            case .sessions:
                sessionList
            case .files:
                filesPane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(WhaleTheme.Color.background)
    }

    private var sessionList: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Menu {
                    Button {
                        appViewModel.createSession(provider: .claude)
                    } label: {
                        Label(AgentProvider.claude.displayName, systemImage: AgentProvider.claude.iconName)
                    }
                    Button {
                        appViewModel.createSession(provider: .cursor)
                    } label: {
                        Label(AgentProvider.cursor.displayName, systemImage: AgentProvider.cursor.iconName)
                    }
                    Button {
                        appViewModel.createSession(provider: .codex)
                    } label: {
                        Label(AgentProvider.codex.displayName, systemImage: AgentProvider.codex.iconName)
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(WhaleTheme.Color.text)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(WhaleTheme.Color.surface))
                }
                .menuIndicator(.hidden)
                .buttonStyle(.plain)
                .help("New Session")
            }
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.bottom, WhaleTheme.Spacing.sm)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(appViewModel.sessions) { session in
                        Button {
                            appViewModel.selectSession(session)
                        } label: {
                            SessionRowView(session: session, isSelected: session.id == appViewModel.selectedSessionID)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete Session", role: .destructive) {
                                appViewModel.deleteSession(session)
                            }
                        }
                    }
                }
                .padding(.horizontal, WhaleTheme.Spacing.sm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var filesPane: some View {
        if let root = appViewModel.selectedProject?.path {
            FilesPane(root: root)
        } else {
            Text("No project open")
                .font(WhaleTheme.Typography.caption(11))
                .foregroundStyle(WhaleTheme.Color.muted)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// The Files tab. With no query it shows the lazy file tree; with a query it runs a VSCode-style
/// content search (text inside files) honoring an exclude-globs field. Clicking a file (in the
/// tree or a result) opens an in-app, syntax-highlighted preview.
private struct FilesPane: View {
    let root: URL

    @State private var query = ""
    @State private var excludeText = FileTree.defaultExcludes
    @State private var showExclude = false
    @State private var useRegex = false
    @State private var matchCase = false
    @State private var refreshToken = 0
    @State private var preview: PreviewItem?
    @State private var search = ContentSearchModel()

    private var excludes: [String] {
        excludeText.split(whereSeparator: { $0 == "," || $0 == "\n" }).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().overlay(WhaleTheme.Color.border)

            if query.isEmpty {
                FileTreeView(root: root, onOpen: { preview = PreviewItem(url: $0, line: nil) })
                    .id(refreshToken)
            } else {
                ContentResultsView(results: search.results, root: root) { url, line in
                    preview = PreviewItem(url: url, line: line)
                }
            }
        }
        .onChange(of: query) { runSearch() }
        .onChange(of: excludeText) { runSearch() }
        .onChange(of: useRegex) { runSearch() }
        .onChange(of: matchCase) { runSearch() }
        .sheet(item: $preview) { item in
            FilePreviewView(url: item.url, highlightLine: item.line) { preview = nil }
        }
    }

    private func runSearch() {
        search.run(root: root, query: query, excludes: excludes, useRegex: useRegex, matchCase: matchCase)
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(WhaleTheme.Color.muted)
                TextField("Search in files…", text: $query)
                    .textFieldStyle(.plain)
                    .font(WhaleTheme.Typography.body(12))
                    .foregroundStyle(WhaleTheme.Color.text)
                toggleChip("Aa", isOn: matchCase, help: "Match Case") { matchCase.toggle() }
                toggleChip(".*", isOn: useRegex, help: "Use Regular Expression") { useRegex.toggle() }
                if !query.isEmpty {
                    iconButton("xmark.circle.fill", help: "Clear") { query = "" }
                }
                iconButton(showExclude ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle",
                           help: "Exclude") { showExclude.toggle() }
                iconButton("arrow.clockwise", help: "Refresh") {
                    refreshToken += 1
                    runSearch()
                }
            }
            .fieldChrome()

            if showExclude {
                HStack(spacing: 6) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(WhaleTheme.Color.muted)
                    TextField("Exclude globs (comma-separated)", text: $excludeText)
                        .textFieldStyle(.plain)
                        .font(WhaleTheme.Typography.caption(11))
                        .foregroundStyle(WhaleTheme.Color.text)
                }
                .fieldChrome()
            }
        }
        .padding(.horizontal, WhaleTheme.Spacing.md)
        .padding(.bottom, WhaleTheme.Spacing.sm)
    }

    private func iconButton(_ systemName: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(WhaleTheme.Color.muted)
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toggleChip(_ text: String, isOn: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(isOn ? WhaleTheme.Color.background : WhaleTheme.Color.muted)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(isOn ? WhaleTheme.Color.secondary : Color.clear))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

private extension View {
    func fieldChrome() -> some View {
        self
            .padding(.horizontal, WhaleTheme.Spacing.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(WhaleTheme.Color.surface))
            .overlay(Capsule().strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
    }
}

private struct PreviewItem: Identifiable {
    let url: URL
    let line: Int?
    var id: String { "\(url.path)#\(line ?? 0)" }
}

// MARK: - File tree (browse)

private struct FileTreeView: View {
    let root: URL
    let onOpen: (URL) -> Void
    @State private var children: [URL]?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let children {
                    ForEach(children, id: \.self) { FileTreeNode(url: $0, depth: 0, onOpen: onOpen) }
                }
            }
            .padding(.horizontal, WhaleTheme.Spacing.sm)
            .padding(.bottom, WhaleTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { if children == nil { children = FileTree.load(root) } }
    }
}

/// A custom disclosure row (not SwiftUI's `DisclosureGroup`) so indentation is explicit per depth
/// — nested folders are clearly offset from their parent. Tap a folder to expand/collapse, tap a
/// file to preview; either drags out as a URL.
private struct FileTreeNode: View {
    let url: URL
    let depth: Int
    let onOpen: (URL) -> Void

    @State private var isExpanded = false
    @State private var children: [URL]?

    private var isDirectory: Bool { FileTree.isDirectory(url) }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            row
            if isDirectory, isExpanded, let children {
                ForEach(children, id: \.self) { FileTreeNode(url: $0, depth: depth + 1, onOpen: onOpen) }
            }
        }
    }

    private var row: some View {
        HStack(spacing: 5) {
            Group {
                if isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(WhaleTheme.Color.muted)
                } else {
                    Color.clear
                }
            }
            .frame(width: 10)

            Image(systemName: isDirectory ? "folder.fill" : FileTree.fileIcon(for: url))
                .font(.system(size: 11))
                .foregroundStyle(isDirectory ? WhaleTheme.Color.secondary : WhaleTheme.Color.muted)
                .frame(width: 14)

            Text(url.lastPathComponent)
                .font(WhaleTheme.Typography.body(12))
                .foregroundStyle(WhaleTheme.Color.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.leading, CGFloat(depth) * 14)
        .contentShape(Rectangle())
        .onTapGesture {
            if isDirectory {
                withAnimation(WhaleTheme.Motion.fast) { isExpanded.toggle() }
                if isExpanded, children == nil { children = FileTree.load(url) }
            } else {
                onOpen(url)
            }
        }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .help(url.path)
    }
}

// MARK: - Content search

private struct ContentMatch: Identifiable, Hashable {
    let url: URL
    let line: Int
    let text: String
    var id: String { "\(url.path):\(line)" }
}

@MainActor
@Observable
private final class ContentSearchModel {
    private(set) var results: [ContentMatch] = []
    private var task: Task<Void, Never>?

    func run(root: URL, query: String, excludes: [String], useRegex: Bool, matchCase: Bool) {
        task?.cancel()
        guard !query.isEmpty else {
            results = []
            return
        }
        task = Task.detached(priority: .userInitiated) { [weak self] in
            let found = FileTree.contentSearch(root, query: query, excludes: excludes, useRegex: useRegex, matchCase: matchCase) { Task.isCancelled }
            if Task.isCancelled { return }
            await MainActor.run { self?.results = found }
        }
    }
}

/// Results grouped by file (VSCode-style): a file header, then its matching lines beneath.
private struct ContentResultsView: View {
    let results: [ContentMatch]
    let root: URL
    let onOpen: (URL, Int?) -> Void

    private var grouped: [(url: URL, matches: [ContentMatch])] {
        var order: [URL] = []
        var map: [URL: [ContentMatch]] = [:]
        for match in results {
            if map[match.url] == nil { order.append(match.url) }
            map[match.url, default: []].append(match)
        }
        return order.map { ($0, map[$0]!) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 2) {
                if results.isEmpty {
                    Text("No matches")
                        .font(WhaleTheme.Typography.caption(11))
                        .foregroundStyle(WhaleTheme.Color.muted)
                        .padding(.vertical, WhaleTheme.Spacing.sm)
                } else {
                    ForEach(grouped, id: \.url) { group in
                        fileHeader(group.url, count: group.matches.count)
                        ForEach(group.matches) { match in
                            matchRow(match)
                        }
                    }
                }
            }
            .padding(.horizontal, WhaleTheme.Spacing.sm)
            .padding(.bottom, WhaleTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func fileHeader(_ url: URL, count: Int) -> some View {
        HStack(spacing: 5) {
            Image(systemName: FileTree.fileIcon(for: url))
                .font(.system(size: 10))
                .foregroundStyle(WhaleTheme.Color.muted)
            Text(url.lastPathComponent)
                .font(WhaleTheme.Typography.body(12).bold())
                .foregroundStyle(WhaleTheme.Color.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("\(count)")
                .font(WhaleTheme.Typography.caption(10))
                .foregroundStyle(WhaleTheme.Color.muted)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
        .padding(.top, 4)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(url, nil) }
        .onDrag { NSItemProvider(object: url as NSURL) }
        .help(FileTree.relativePath(url, root: root))
    }

    private func matchRow(_ match: ContentMatch) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(match.line)")
                .font(WhaleTheme.Typography.mono(12))
                .foregroundStyle(WhaleTheme.Color.muted)
                .frame(minWidth: 30, alignment: .trailing)
            Text(match.text)
                .font(WhaleTheme.Typography.mono(13))
                .foregroundStyle(WhaleTheme.Color.text.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .padding(.leading, WhaleTheme.Spacing.md)
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onTapGesture { onOpen(match.url, match.line) }
    }
}

// MARK: - In-app file preview (syntax highlighted)

/// In-app file preview rendered line by line (so a clicked search match can scroll to and tint
/// its exact line), with per-line syntax highlighting and a line-number gutter — styled on the
/// shared `Code` palette.
private struct FilePreviewView: View {
    let url: URL
    let highlightLine: Int?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: FileTree.fileIcon(for: url))
                    .foregroundStyle(WhaleTheme.Color.accent)
                Text(url.lastPathComponent)
                    .font(WhaleTheme.Typography.body().bold())
                    .foregroundStyle(WhaleTheme.Color.text)
                Spacer()
                Button("Done", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
            .padding(WhaleTheme.Spacing.md)

            Divider().overlay(WhaleTheme.Color.border)

            content
        }
        .frame(minWidth: 640, idealWidth: 820, minHeight: 480, idealHeight: 600)
        .background(WhaleTheme.Color.background)
    }

    @ViewBuilder
    private var content: some View {
        if let lines = loadLines() {
            // Skip highlighting very large files — the single-pass highlighter would stall.
            let language = lines.count < 6000 ? FileTree.language(for: url) : nil
            GeometryReader { geo in
                ScrollViewReader { proxy in
                    ScrollView([.vertical, .horizontal]) {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                                lineRow(number: index + 1, text: line, language: language)
                                    .id(index + 1)
                            }
                        }
                        .padding(.vertical, WhaleTheme.Spacing.sm)
                        // Fill the viewport when content is narrow, but still grow (and scroll
                        // horizontally) when a line is wider than the pane.
                        .frame(minWidth: geo.size.width, alignment: .leading)
                    }
                    .background(WhaleTheme.Code.background)
                    .onAppear {
                        if let target = highlightLine {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                withAnimation { proxy.scrollTo(target, anchor: .center) }
                            }
                        }
                    }
                }
            }
        } else {
            VStack {
                Spacer()
                Text("Can't preview this file (binary or larger than 2 MB).")
                    .font(WhaleTheme.Typography.caption())
                    .foregroundStyle(WhaleTheme.Color.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func lineRow(number: Int, text: String, language: String?) -> some View {
        let isTarget = number == highlightLine
        return HStack(alignment: .top, spacing: WhaleTheme.Spacing.sm) {
            Text("\(number)")
                .font(WhaleTheme.Typography.mono(12))
                .foregroundStyle(WhaleTheme.Code.muted)
                .frame(minWidth: 40, alignment: .trailing)
            Text(CodeSyntaxHighlighter.highlight(text.isEmpty ? " " : text, language: language))
                .font(WhaleTheme.Typography.mono(13))
                .foregroundStyle(WhaleTheme.Code.text)
                .textSelection(.enabled)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, WhaleTheme.Spacing.md)
        .padding(.vertical, 1)
        .background(isTarget ? WhaleTheme.Color.secondary.opacity(0.22) : Color.clear)
    }

    private func loadLines() -> [String]? {
        guard let data = try? Data(contentsOf: url), data.count < 2_000_000,
              !data.prefix(8000).contains(0),
              let text = String(data: data, encoding: .utf8) else { return nil }
        return text.components(separatedBy: "\n")
    }
}

// MARK: - File-system helpers

private enum FileTree {
    /// Names skipped regardless of hidden status — bulky/noise dirs that aren't useful.
    static let ignored: Set<String> = ["node_modules", "build", "dist", "DerivedData", ".build", ".git"]

    /// Prefilled exclude field — VSCode-style comma-separated globs.
    static let defaultExcludes = "node_modules, .git, dist, build, DerivedData, *.lock, *.min.*"

    static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }

    static func load(_ directory: URL) -> [URL] {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return items
            .filter { !ignored.contains($0.lastPathComponent) }
            .sorted { a, b in
                let ad = isDirectory(a), bd = isDirectory(b)
                if ad != bd { return ad }
                return a.lastPathComponent.localizedCaseInsensitiveCompare(b.lastPathComponent) == .orderedAscending
            }
    }

    static func relativePath(_ url: URL, root: URL) -> String {
        let full = url.path, base = root.path
        guard full.hasPrefix(base) else { return full }
        return String(full.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func matchesExclude(_ url: URL, root: URL, excludes: [String]) -> Bool {
        guard !excludes.isEmpty else { return false }
        let name = url.lastPathComponent
        let rel = relativePath(url, root: root)
        for pattern in excludes {
            // A bare name (no glob) excludes any path component with that name.
            if !pattern.contains("*") && !pattern.contains("/") {
                if name == pattern { return true }
            }
            if fnmatch(pattern, name, 0) == 0 { return true }
            if fnmatch(pattern, rel, 0) == 0 { return true }
        }
        return false
    }

    /// VSCode-style content search: bounded recursive walk, skipping hidden/ignored/excluded paths
    /// and binary or oversized files; matches case-insensitive substrings line by line.
    static func contentSearch(
        _ root: URL,
        query: String,
        excludes: [String],
        useRegex: Bool = false,
        matchCase: Bool = false,
        limit: Int = 400,
        maxFileSize: Int = 1_000_000,
        isCancelled: () -> Bool = { false }
    ) -> [ContentMatch] {
        guard !query.isEmpty else { return [] }

        // Compile once; an invalid regex yields no results rather than erroring out the UI.
        let regex: NSRegularExpression?
        if useRegex {
            let options: NSRegularExpression.Options = matchCase ? [] : [.caseInsensitive]
            guard let compiled = try? NSRegularExpression(pattern: query, options: options) else { return [] }
            regex = compiled
        } else {
            regex = nil
        }
        let plainOptions: String.CompareOptions = matchCase ? [] : [.caseInsensitive]

        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var out: [ContentMatch] = []
        for case let url as URL in enumerator {
            if isCancelled() || out.count >= limit { break }

            let name = url.lastPathComponent
            if ignored.contains(name) || matchesExclude(url, root: root, excludes: excludes) {
                if isDirectory(url) { enumerator.skipDescendants() }
                continue
            }
            if isDirectory(url) { continue }

            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxFileSize { continue }
            guard let data = try? Data(contentsOf: url) else { continue }
            if data.prefix(8000).contains(0) { continue } // binary
            guard let content = String(data: data, encoding: .utf8) else { continue }

            var lineNo = 0
            for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
                lineNo += 1
                let matched: Bool
                if let regex {
                    let s = String(line)
                    matched = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
                } else {
                    matched = line.range(of: query, options: plainOptions) != nil
                }
                if matched {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    out.append(ContentMatch(url: url, line: lineNo, text: String(trimmed.prefix(200))))
                    if out.count >= limit { break }
                }
            }
        }
        return out
    }

    /// SF Symbol per file type — purely cosmetic, falls back to a generic doc. Only well-known
    /// symbol names are used so nothing renders blank.
    static func fileIcon(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "mjs", "cjs", "ts", "tsx", "json": return "curlybraces"
        case "py", "go", "rs", "rb", "c", "h", "cpp", "cc", "hpp", "cxx", "java", "kt", "php": return "chevron.left.forwardslash.chevron.right"
        case "html", "htm", "xml": return "chevron.left.forwardslash.chevron.right"
        case "css", "scss", "sass", "less": return "paintbrush"
        case "yml", "yaml", "toml", "ini", "cfg", "conf", "plist", "entitlements": return "gearshape"
        case "md", "markdown", "txt", "rtf": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "heic", "svg", "icns": return "photo"
        case "pdf": return "doc.richtext"
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "rar", "7z", "dmg": return "archivebox"
        case "sh", "bash", "zsh", "fish", "command": return "terminal"
        case "lock": return "lock"
        default: return "doc"
        }
    }

    static func language(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "swift": return "swift"
        case "js", "jsx", "mjs", "cjs": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "sh", "bash", "zsh": return "bash"
        case "go": return "go"
        case "rs": return "rust"
        case "rb": return "ruby"
        case "c", "h": return "c"
        case "cpp", "cc", "hpp", "cxx": return "cpp"
        case "java", "kt": return "java"
        case "json": return "json"
        case "yml", "yaml": return "yaml"
        default: return nil
        }
    }
}
