import Foundation

@MainActor
final class ChatViewModel {
    private(set) var messages: [Message] = [] {
        didSet {
            onMessagesUpdated?(messages)
        }
    }

    var username: String {
        didSet {
            UserDefaults.standard.set(username, forKey: Self.usernameKey)
        }
    }

    var onMessagesUpdated: (([Message]) -> Void)?
    var onError: ((String) -> Void)?

    private let chatService: ChatService
    private var pollingTask: Task<Void, Never>?
    private var lastFetchedDate: Date?

    private static let usernameKey = "chat.username"

    init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        self.username = UserDefaults.standard.string(forKey: Self.usernameKey) ?? ""
        startPolling()
    }

    func updateUsername(_ newName: String) -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        username = trimmed
        return true
    }

    func sendMessage(content: String) async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !username.isEmpty else { return }

        do {
            let message = try await chatService.sendMessage(content: trimmed, author: username)
            appendMessages([message])
        } catch {
            onError?(error.localizedDescription)
        }
    }

    func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let newMessages = try await self.chatService.fetchMessages(since: self.lastFetchedDate)
                    await MainActor.run {
                        self.appendMessages(newMessages)
                        if let latestDate = newMessages.map(\.timestamp).max() {
                            self.lastFetchedDate = latestDate
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.onError?(error.localizedDescription)
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }

    private func appendMessages(_ newMessages: [Message]) {
        guard !newMessages.isEmpty else { return }
        var merged: [String: Message] = Dictionary(uniqueKeysWithValues: messages.map { ($0.id, $0) })
        for message in newMessages {
            merged[message.id] = message
        }
        messages = merged.values.sorted(by: { $0.timestamp < $1.timestamp })
    }
}
