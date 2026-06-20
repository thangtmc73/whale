import SwiftUI

/// The right panel — a live terminal showing the selected session's raw CLI output (exactly what
/// the underlying process emitted: JSON events, shell commands, exit codes), so the user can see
/// what's actually running beneath the formatted timeline. Styled with the shared `Code` palette
/// so it reads as a real terminal slab in both light and dark appearance.
///
/// (Provider / model / session metadata used to live here; provider & model now live in the
/// composer, so this panel is dedicated to the terminal.)
struct SessionTerminalView: View {
    var viewModel: SessionViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "terminal")
                    .font(.system(size: 10, weight: .semibold))
                Text("Terminal")
                    .font(WhaleTheme.Typography.heading(12))
                    .tracking(0.5)
                Spacer()
                if !viewModel.rawLog.isEmpty {
                    Text("\(viewModel.rawLog.count) lines")
                        .font(WhaleTheme.Typography.caption(10))
                }
            }
            .foregroundStyle(WhaleTheme.Code.muted)
            .padding(.horizontal, WhaleTheme.Spacing.md)
            .padding(.vertical, WhaleTheme.Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WhaleTheme.Code.header)

            Divider().overlay(WhaleTheme.Code.border)

            terminalBody
        }
        .background(WhaleTheme.Code.background)
    }

    @ViewBuilder
    private var terminalBody: some View {
        if viewModel.rawLog.isEmpty {
            VStack {
                Spacer()
                Text("No output yet — send a prompt to see what runs.")
                    .font(WhaleTheme.Typography.caption(11))
                    .foregroundStyle(WhaleTheme.Code.muted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WhaleTheme.Spacing.md)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView([.vertical, .horizontal]) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(viewModel.rawLog.enumerated()), id: \.offset) { index, line in
                            Text(line.isEmpty ? " " : line)
                                .font(WhaleTheme.Typography.mono(11))
                                .foregroundStyle(WhaleTheme.Code.text)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(index)
                        }
                        Color.clear.frame(height: 1).id("term-bottom")
                    }
                    .padding(.horizontal, WhaleTheme.Spacing.md)
                    .padding(.vertical, WhaleTheme.Spacing.sm)
                }
                .onChange(of: viewModel.rawLog.count) {
                    withAnimation(WhaleTheme.Motion.fast) {
                        proxy.scrollTo("term-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
}
