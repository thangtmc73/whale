import Foundation

/// Flat JSON-file-backed CRUD for the session list, same approach as ProjectStore — gets
/// migrated to SQLite/GRDB in M5 once cross-provider discovery needs real upsert queries.
final class SessionStore {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("Whale", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("sessions.json")
    }

    func load() -> [Session] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Session].self, from: data)) ?? []
    }

    func loadSessions(forProject projectID: UUID) -> [Session] {
        load()
            .filter { $0.projectID == projectID }
            .sorted { $0.lastActivityAt > $1.lastActivityAt }
    }

    func save(_ sessions: [Session]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func upsert(_ session: Session) {
        var sessions = load()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        save(sessions)
    }

    /// Removes only Whale's own index entry — never touches the provider's own session/
    /// transcript files on disk.
    func delete(_ sessionID: UUID) {
        var sessions = load()
        sessions.removeAll { $0.id == sessionID }
        save(sessions)
    }
}
