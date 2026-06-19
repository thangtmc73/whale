import Foundation
import Observation

@Observable
final class AppViewModel {
    private(set) var projects: [Project] = []
    private(set) var selectedProject: Project?
    private(set) var sessions: [Session] = []
    private(set) var selectedSessionID: UUID?
    private(set) var currentGitBranch: String?

    private let projectStore = ProjectStore()
    private let sessionStore = SessionStore()
    private var sessionViewModels: [UUID: SessionViewModel] = [:]

    init() {
        projects = projectStore.load()
        // Restore the last-opened project automatically — without this, every relaunch lands on
        // the empty "Open a project" screen even though all its sessions are still on disk,
        // which reads as "my old sessions disappeared" when they're actually just one click away.
        if let lastProject = projects.max(by: { $0.lastOpenedAt < $1.lastOpenedAt }) {
            select(lastProject)
        }
    }

    var selectedSessionViewModel: SessionViewModel? {
        selectedSessionID.flatMap { sessionViewModels[$0] }
    }

    func addProject(at url: URL) {
        var project = projects.first { $0.path == url } ?? Project(path: url)
        project.lastOpenedAt = .now
        projectStore.upsert(project)
        projects = projectStore.load()
        select(project)
    }

    func select(_ project: Project) {
        selectedProject = project
        currentGitBranch = GitBranchReader.currentBranch(at: project.path)
        sessionViewModels = [:]
        sessions = sessionStore.loadSessions(forProject: project.id)

        if let first = sessions.first {
            selectSession(first)
        } else {
            createSession(provider: .claude)
        }
    }

    @discardableResult
    func createSession(provider: AgentProvider, draftText: String = "", displayName: String? = nil) -> Session {
        let session = Session(
            projectID: selectedProject!.id,
            provider: provider,
            cliSessionID: UUID().uuidString,
            displayName: displayName
        )
        sessions.insert(session, at: 0)
        sessionStore.upsert(session)
        selectSession(session)
        // A non-empty draftText here is a cross-provider context handoff — auto-forward it
        // immediately rather than just prefilling the composer, so the new provider already has
        // the full conversation without the user needing to manually hit Send.
        if !draftText.isEmpty {
            sessionViewModels[session.id]?.send(prompt: draftText)
        }
        return session
    }

    func selectSession(_ session: Session) {
        selectedSessionID = session.id
        guard sessionViewModels[session.id] == nil, let project = selectedProject else { return }
        let model = session.lastModel.flatMap { id in
            ModelCatalog.options(for: session.provider).first { $0.id == id }
        } ?? ModelCatalog.defaultOption(for: session.provider)

        let viewModel = SessionViewModel(
            session: session,
            project: project,
            model: model,
            onSessionUpdated: { [weak self] updated in
                self?.persist(updated)
            }
        )
        viewModel.onSwitchProvider = { [weak self] newProvider, handoff, title in
            self?.createSession(provider: newProvider, draftText: handoff, displayName: title)
        }
        sessionViewModels[session.id] = viewModel
    }

    private func persist(_ session: Session) {
        sessionStore.upsert(session)
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    /// Only removes Whale's own index/live view-model for this session — the underlying
    /// CLI's own transcript file (if any) is left untouched.
    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        sessionViewModels.removeValue(forKey: session.id)
        sessionStore.delete(session.id)

        guard selectedSessionID == session.id else { return }
        if let next = sessions.first {
            selectSession(next)
        } else {
            createSession(provider: .claude)
        }
    }
}
