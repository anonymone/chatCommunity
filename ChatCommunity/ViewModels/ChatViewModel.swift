import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText: String = ""
    @Published var errorMessage: String?
    @Published var isPresentingNameSheet = false

    var username: String = ""

    private let chatService: ChatService
    private var pollingTask: Task<Void, Never>?
    private var lastFetchedDate: Date?

    var canSendMessage: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !username.isEmpty
    }

    init(chatService: ChatService = ChatService()) {
        self.chatService = chatService
        startPolling()
    }

    func updateUsername(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        username = trimmed
        UserDefaults.standard.set(trimmed, forKey: "chat.username")
        isPresentingNameSheet = false
    }

    func sendMessage() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !username.isEmpty else { return }
        inputText = ""

        do {
            let message = try await chatService.sendMessage(content: content, author: username)
            appendMessages([message])
        } catch {
            self.errorMessage = error.localizedDescription
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
                        self.errorMessage = error.localizedDescription
                    }
                }
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func appendMessages(_ newMessages: [Message]) {
        guard !newMessages.isEmpty else { return }
        var combined = messages
        for message in newMessages {
            if !combined.contains(where: { $0.id == message.id }) {
                combined.append(message)
            }
        }
        combined.sort(by: { $0.timestamp < $1.timestamp })
        messages = combined
    }
}
