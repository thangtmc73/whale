import SwiftUI

struct StepTimelineView: View {
    let turns: [Turn]
    var onFileEditDecision: (UUID, FileEditDecision) -> Void = { _, _ in }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Pinned section headers: while scrolling through a turn's steps, that turn's
                // prompt stays stuck to the top so it's always clear which question the answer
                // below belongs to — swaps to the next prompt once its section reaches the top.
                LazyVStack(alignment: .leading, spacing: WhaleTheme.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                    ForEach(turns) { turn in
                        Section {
                            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
                                ForEach(turn.steps) { step in
                                    StepRowView(step: step, onFileEditDecision: onFileEditDecision)
                                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                            .padding(.horizontal, WhaleTheme.Spacing.lg)
                        } header: {
                            promptHeader(turn)
                        }
                        .id(turn.id)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.vertical, WhaleTheme.Spacing.lg)
                .animation(WhaleTheme.Motion.normal, value: turns.last?.steps.count)
            }
            .background(WhaleTheme.Color.background)
            .onChange(of: turns.last?.steps.count) {
                withAnimation(WhaleTheme.Motion.fast) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    /// Sits on its own full-bleed opaque background (not just the bubble's) so that when this
    /// header is pinned at the scroll view's top, it fully occludes content scrolling underneath
    /// instead of letting it show through a translucent edge.
    @ViewBuilder
    private func promptHeader(_ turn: Turn) -> some View {
        promptText(for: turn)
            .font(WhaleTheme.Typography.body(13))
            .foregroundStyle(WhaleTheme.Color.text)
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.vertical, WhaleTheme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: WhaleTheme.Radius.medium)
                    .fill(WhaleTheme.Color.primary.opacity(0.14))
            )
            .overlay(
                RoundedRectangle(cornerRadius: WhaleTheme.Radius.medium)
                    .strokeBorder(WhaleTheme.Color.primary.opacity(0.25), lineWidth: 1)
            )
            .padding(.horizontal, WhaleTheme.Spacing.lg)
            .padding(.bottom, WhaleTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WhaleTheme.Color.background)
    }

    /// Renders the sent prompt, replacing each attachment's absolute path with a highlighted
    /// inline token (folder/file icon + name) so dropped files read the same way they looked as
    /// chips in the composer. Longest paths are matched first so a nested path isn't split.
    private func promptText(for turn: Turn) -> Text {
        guard !turn.attachments.isEmpty else { return Text(turn.promptText) }

        let byLengthDesc = turn.attachments.sorted { $0.path.count > $1.path.count }
        var result = Text("")
        var rest = Substring(turn.promptText)

        while !rest.isEmpty {
            var earliest: (range: Range<Substring.Index>, url: URL)?
            for url in byLengthDesc {
                guard let range = rest.range(of: url.path) else { continue }
                if earliest == nil || range.lowerBound < earliest!.range.lowerBound {
                    earliest = (range, url)
                }
            }
            guard let hit = earliest else {
                result = result + Text(String(rest))
                break
            }
            if hit.range.lowerBound > rest.startIndex {
                result = result + Text(String(rest[rest.startIndex..<hit.range.lowerBound]))
            }
            result = result + attachmentToken(for: hit.url)
            rest = rest[hit.range.upperBound...]
        }
        return result
    }

    private func attachmentToken(for url: URL) -> Text {
        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        let icon = isDirectory ? "folder.fill" : FileTree.fileIcon(for: url)
        return Text("\(Image(systemName: icon)) \(url.lastPathComponent)")
            .foregroundColor(WhaleTheme.Color.secondary)
            .fontWeight(.semibold)
    }
}
