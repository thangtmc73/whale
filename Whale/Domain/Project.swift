import Foundation

struct Project: Identifiable, Codable, Hashable {
    let id: UUID
    var path: URL
    var displayName: String
    var addedAt: Date
    var lastOpenedAt: Date

    init(id: UUID = UUID(), path: URL, displayName: String? = nil, addedAt: Date = .now, lastOpenedAt: Date = .now) {
        self.id = id
        self.path = path
        self.displayName = displayName ?? path.lastPathComponent
        self.addedAt = addedAt
        self.lastOpenedAt = lastOpenedAt
    }
}
