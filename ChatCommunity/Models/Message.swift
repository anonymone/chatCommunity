import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let author: String
    let content: String
    let timestamp: Date

    var timestampFormatted: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }

    static let mock = Message(id: UUID().uuidString,
                              author: "Codex",
                              content: "Hello from the mock server",
                              timestamp: Date())
}

struct SendMessageRequest: Codable {
    let author: String
    let content: String
}
