import Foundation

/// One turn in the AI Judge transcript.
struct ChatMessage: Codable, Identifiable, Hashable {
    var id: UUID
    var role: Role
    var text: String
    var sentAt: Date

    enum Role: String, Codable, Hashable {
        case user
        case judge
        case system
    }

    init(id: UUID = UUID(), role: Role, text: String, sentAt: Date = Date()) {
        self.id = id
        self.role = role
        self.text = text
        self.sentAt = sentAt
    }
}
