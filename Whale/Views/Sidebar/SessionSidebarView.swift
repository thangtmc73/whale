import SwiftUI

/// A hand-rolled list (not `List`/`.sidebar` style) so every color is under our control — the
/// system sidebar material fights a custom dark palette (it stays vibrant/translucent regardless
/// of background color), which doesn't fit the calm, flat "Linear/Raycast" look the brief wants.
struct SessionSidebarView: View {
    let appViewModel: AppViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Sessions")
                    .font(WhaleTheme.Typography.heading(12))
                    .foregroundStyle(WhaleTheme.Color.muted)
                    .tracking(0.5)
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
            .padding(.top, WhaleTheme.Spacing.md)
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
        .background(WhaleTheme.Color.background)
    }
}
