import SwiftUI

/// The brief's "Right Panel": provider switcher, model info, session metadata — collapsible via
/// the toolbar toggle in RootView. Read-only display except for the provider/model switch
/// affordances, which simply call back into the same SessionViewModel logic the main toolbar uses.
struct SessionInspectorView: View {
    var viewModel: SessionViewModel
    let gitBranch: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: WhaleTheme.Spacing.lg) {
                section("Provider") {
                    HStack(spacing: WhaleTheme.Spacing.sm) {
                        Image(systemName: viewModel.session.provider.iconName)
                            .foregroundStyle(WhaleTheme.Color.accent)
                        Text(viewModel.session.provider.displayName)
                            .font(WhaleTheme.Typography.body())
                            .foregroundStyle(WhaleTheme.Color.text)
                    }
                }

                section("Model") {
                    Text(viewModel.selectedModel.displayName)
                        .font(WhaleTheme.Typography.body())
                        .foregroundStyle(WhaleTheme.Color.text)
                }

                section("Session") {
                    VStack(alignment: .leading, spacing: WhaleTheme.Spacing.xs) {
                        metadataRow("Created", value: viewModel.session.createdAt.formatted(date: .abbreviated, time: .shortened))
                        metadataRow("Last activity", value: viewModel.session.lastActivityAt.formatted(date: .abbreviated, time: .shortened))
                        metadataRow("CLI session", value: viewModel.session.cliSessionID)
                    }
                }

                if let gitBranch, !gitBranch.isEmpty {
                    section("Git branch") {
                        Text(gitBranch)
                            .font(WhaleTheme.Typography.mono())
                            .foregroundStyle(WhaleTheme.Color.secondary)
                    }
                }
            }
            .padding(WhaleTheme.Spacing.lg)
        }
        .background(WhaleTheme.Color.background)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: WhaleTheme.Spacing.sm) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WhaleTheme.Color.muted)
                .tracking(0.5)
            content()
        }
        .padding(WhaleTheme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .whaleSurface(cornerRadius: WhaleTheme.Radius.medium)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: WhaleTheme.Spacing.sm) {
            Text(label)
                .font(WhaleTheme.Typography.caption())
                .foregroundStyle(WhaleTheme.Color.muted)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(WhaleTheme.Typography.caption())
                .foregroundStyle(WhaleTheme.Color.text)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}
