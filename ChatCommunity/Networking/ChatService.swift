import Foundation

struct ChatService {
    enum ServiceError: LocalizedError {
        case invalidURL
        case invalidResponse
        case decodingError
        case server(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "服务器地址不正确"
            case .invalidResponse: return "服务器响应不可用"
            case .decodingError: return "响应解析失败"
            case .server(let message): return message
            }
        }
    }

    private let session: URLSession
    private let configuration: ServerConfiguration
    private let jsonDecoder: JSONDecoder
    private let jsonEncoder: JSONEncoder
    private let isMock: Bool

    init(configuration: ServerConfiguration = .live,
         session: URLSession = .shared,
         mock: Bool = false) {
        self.configuration = configuration
        self.session = session
        self.isMock = mock
        self.jsonDecoder = JSONDecoder()
        jsonDecoder.dateDecodingStrategy = .iso8601
        self.jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
    }

    func sendMessage(content: String, author: String) async throws -> Message {
        if isMock {
            return Message(id: UUID().uuidString, author: author, content: content, timestamp: .now)
        }

        guard let url = configuration.baseURL?.appending(path: configuration.messagePath) else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try jsonEncoder.encode(SendMessageRequest(author: author, content: content))

        let (data, response) = try await session.data(for: request)
        try response.validate()

        guard let message = try? jsonDecoder.decode(Message.self, from: data) else {
            throw ServiceError.decodingError
        }

        return message
    }

    func fetchMessages(since: Date?) async throws -> [Message] {
        if isMock {
            return [.mock]
        }

        guard var urlComponents = configuration.components else {
            throw ServiceError.invalidURL
        }

        if let since {
            let formatter = ISO8601DateFormatter()
            urlComponents.queryItems = [URLQueryItem(name: "since", value: formatter.string(from: since))]
        }

        guard let url = urlComponents.url else {
            throw ServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        try response.validate()

        guard let messages = try? jsonDecoder.decode([Message].self, from: data) else {
            throw ServiceError.decodingError
        }

        return messages
    }
}

extension URLResponse {
    func validate() throws {
        guard let http = self as? HTTPURLResponse else {
            throw ChatService.ServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw ChatService.ServiceError.server(message)
        }
    }
}
