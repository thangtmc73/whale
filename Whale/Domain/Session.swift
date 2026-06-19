import Foundation

enum SessionOrigin: String, Codable {
    case createdByApp
    case discovered
}

struct Session: Identifiable, Codable, Hashable {
    let id: UUID
    let projectID: UUID
    var provider: AgentProvider
    /// Provider-native session reference: Claude's session UUID, Cursor's chatId, Codex's session id.
    var cliSessionID: String
    var displayName: String?
    var lastModel: String?
    var createdAt: Date
    var lastActivityAt: Date
    var origin: SessionOrigin
    /// Whether a turn has actually been sent under `cliSessionID` yet — determines whether the
    /// next turn must use `--session-id` (first time) or `--resume` (continuing), and survives
    /// app relaunches since it's persisted alongside the session.
    var hasBeenStarted: Bool

    init(
        id: UUID = UUID(),
        projectID: UUID,
        provider: AgentProvider,
        cliSessionID: String,
        displayName: String? = nil,
        lastModel: String? = nil,
        createdAt: Date = .now,
        lastActivityAt: Date = .now,
        origin: SessionOrigin = .createdByApp,
        hasBeenStarted: Bool = false
    ) {
        self.id = id
        self.projectID = projectID
        self.provider = provider
        self.cliSessionID = cliSessionID
        self.displayName = displayName
        self.lastModel = lastModel
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.origin = origin
        self.hasBeenStarted = hasBeenStarted
    }
}
