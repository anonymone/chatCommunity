import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: String
    let author: String
    var content: String
    let timestamp: Date
    var isComplete: Bool = true

    var timestampFormatted: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }

    static let mock = Message(id: UUID().uuidString,
                              author: "Codex",
                              content: "Hello from the mock server",
                              timestamp: Date())
}

extension Message {
    enum CodingKeys: String, CodingKey {
        case id
        case author
        case content
        case timestamp
        case isComplete = "complete"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        author = try container.decode(String.self, forKey: .author)
        content = try container.decode(String.self, forKey: .content)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(author, forKey: .author)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isComplete, forKey: .isComplete)
    }
}

struct SendMessageRequest: Codable {
    let author: String
    let content: String
}
