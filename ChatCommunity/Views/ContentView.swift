import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: ChatViewModel
    @AppStorage("chat.username") private var storedUsername: String = ""
    @State private var usernameInput: String = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MessageList(messages: viewModel.messages, currentAuthor: viewModel.username)
                Divider()
                messageComposer
                    .padding(.horizontal)
                    .padding(.bottom)
                    .background(Color(uiColor: .systemBackground))
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded {
                isInputFocused = false
            })
            .navigationTitle("ChatCommunity")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        usernameInput = viewModel.username
                        viewModel.isPresentingNameSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle")
                    }
                    .accessibilityLabel("Change display name")
                }
            }
            .sheet(isPresented: $viewModel.isPresentingNameSheet) {
                NavigationStack {
                    Form {
                        Section("昵称") {
                            TextField("输入昵称", text: $usernameInput)
                        }
                    }
                    .navigationTitle("设置昵称")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("取消") {
                                viewModel.isPresentingNameSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("保存") {
                                viewModel.updateUsername(usernameInput)
                                usernameInput = ""
                            }
                            .disabled(usernameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
            }
        }
        .task {
            if storedUsername.isEmpty {
                viewModel.isPresentingNameSheet = true
            } else {
                viewModel.updateUsername(storedUsername)
            }
        }
        .alert("出错了", isPresented: Binding(get: {
            viewModel.errorMessage != nil
        }, set: { newValue in
            if !newValue {
                viewModel.errorMessage = nil
            }
        })) {
            Button("好", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }

    private var messageComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("输入消息", text: $viewModel.inputText, axis: .vertical)
                .focused($isInputFocused)
                .textFieldStyle(.roundedBorder)

            Button {
                Task {
                    await viewModel.sendMessage()
                }
            } label: {
                Image(systemName: viewModel.canSendMessage ? "paperplane.fill" : "paperplane")
                    .font(.system(size: 20))
            }
            .disabled(!viewModel.canSendMessage)
        }
    }
}

struct MessageList: View {
    let messages: [Message]
    let currentAuthor: String

    var body: some View {
        ScrollViewReader { proxy in
            List(messages) { message in
                MessageBubble(message: message, isCurrentUser: message.author == currentAuthor)
                    .listRowSeparator(.hidden)
                    .id(message.id)
            }
            .listStyle(.plain)
            .onChange(of: messages.count) { _ in
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool

    var body: some View {
        HStack {
            if isCurrentUser { Spacer(minLength: 40) }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(message.content)
                    .padding(10)
                    .foregroundStyle(isCurrentUser ? .white : .primary)
                    .background(isCurrentUser ? Color.accentColor : Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(message.timestampFormatted)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if !isCurrentUser { Spacer(minLength: 40) }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(ChatViewModel(chatService: ChatService(mock: true)))
}
