import UIKit

@MainActor
final class ChatViewController: UIViewController {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputContainer = UIView()
    private let messageTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let sendButton = UIButton(type: .system)
    private var inputBottomConstraint: NSLayoutConstraint?
    private var textViewHeightConstraint: NSLayoutConstraint?

    private let viewModel: ChatViewModel
    private var messages: [Message] = []
    private var isReadingHistory = false

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "ChatCommunity"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "昵称",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(changeNameTapped))
        configureTableView()
        configureInputBar()
        configureViewModel()
        registerKeyboardNotifications()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewModel.username.isEmpty {
            presentUsernamePrompt()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func configureTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsSelection = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseIdentifier)
        view.addSubview(tableView)

        inputContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputContainer)

        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBottomConstraint?.isActive = true

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainer.topAnchor),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func configureInputBar() {
        inputContainer.backgroundColor = UIColor.secondarySystemBackground

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false

        messageTextView.delegate = self
        messageTextView.font = UIFont.preferredFont(forTextStyle: .body)
        messageTextView.layer.cornerRadius = 16
        messageTextView.layer.borderWidth = 1
        messageTextView.layer.borderColor = UIColor.quaternaryLabel.cgColor
        messageTextView.isScrollEnabled = false
        messageTextView.backgroundColor = .systemBackground
        messageTextView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

        placeholderLabel.text = "输入消息"
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.font = messageTextView.font
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        messageTextView.addSubview(placeholderLabel)

        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.isEnabled = false

        stack.addArrangedSubview(messageTextView)
        stack.addArrangedSubview(sendButton)

        inputContainer.addSubview(stack)

        textViewHeightConstraint = messageTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 38)
        textViewHeightConstraint?.isActive = true

        NSLayoutConstraint.activate([
            placeholderLabel.leadingAnchor.constraint(equalTo: messageTextView.leadingAnchor, constant: 16),
            placeholderLabel.topAnchor.constraint(equalTo: messageTextView.topAnchor, constant: 10),

            stack.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -12),

            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32)
        ])

        updateSendButtonState()
    }

    private func configureViewModel() {
        viewModel.onMessagesUpdated = { [weak self] messages in
            guard let self else { return }
            let wasNearBottom = self.isTableViewNearBottom()
            self.messages = messages
            self.tableView.reloadData()
            if !self.isReadingHistory || wasNearBottom {
                self.scrollToBottom(animated: true)
            }
        }

        viewModel.onError = { [weak self] message in
            guard let self else { return }
            let alert = UIAlertController(title: "出错了", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "好", style: .cancel))
            self.present(alert, animated: true)
        }

        messages = viewModel.messages
        tableView.reloadData()
        scrollToBottom(animated: false)
    }

    private func registerKeyboardNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleKeyboard(notification:)),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleKeyboard(notification:)),
                                               name: UIResponder.keyboardWillHideNotification,
                                               object: nil)
    }

    @objc private func changeNameTapped() {
        presentUsernamePrompt()
    }

    @objc private func sendTapped() {
        let text = messageTextView.text ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !viewModel.username.isEmpty else {
            presentUsernamePrompt()
            return
        }
        messageTextView.text = ""
        textViewDidChange(messageTextView)
        isReadingHistory = false

        Task { [weak self] in
            await self?.viewModel.sendMessage(content: text)
        }
    }

    private func presentUsernamePrompt() {
        let alert = UIAlertController(title: "设置昵称", message: nil, preferredStyle: .alert)
        alert.addTextField { [weak self] textField in
            textField.placeholder = "输入昵称"
            textField.text = self?.viewModel.username
        }
        let saveAction = UIAlertAction(title: "保存", style: .default) { [weak self, weak alert] _ in
            guard let name = alert?.textFields?.first?.text else { return }
            if self?.viewModel.updateUsername(name) == true {
                self?.updateSendButtonState()
            } else {
                self?.presentUsernamePrompt()
            }
        }
        let cancelAction = UIAlertAction(title: "取消", style: .cancel)
        alert.addAction(cancelAction)
        alert.addAction(saveAction)
        present(alert, animated: true)
    }

    private func updateSendButtonState() {
        let hasText = !(messageTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        sendButton.isEnabled = hasText && !viewModel.username.isEmpty
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let lastRow = messages.count - 1
        let indexPath = IndexPath(row: lastRow, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    private func isTableViewNearBottom(threshold: CGFloat = 60) -> Bool {
        guard tableView.numberOfRows(inSection: 0) > 0 else { return true }
        let contentHeight = tableView.contentSize.height
        let visibleHeight = tableView.bounds.height
        let offsetY = tableView.contentOffset.y
        return contentHeight - (offsetY + visibleHeight) <= threshold
    }

    @objc private func handleKeyboard(notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        let duration = (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
        let curveRaw = (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let curve = UIView.AnimationOptions(rawValue: curveRaw << 16)

        var bottomInset: CGFloat = 0
        if let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            let converted = view.convert(keyboardFrame, from: view.window)
            if converted.origin.y < view.bounds.height {
                bottomInset = view.bounds.maxY - converted.origin.y
            }
        }

        inputBottomConstraint?.constant = -bottomInset
        UIView.animate(withDuration: duration, delay: 0, options: [curve]) {
            self.view.layoutIfNeeded()
        }
    }
}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseIdentifier,
                                                       for: indexPath) as? MessageCell else {
            return UITableViewCell()
        }
        let message = messages[indexPath.row]
        let isCurrentUser = message.author == viewModel.username
        cell.configure(with: message, isCurrentUser: isCurrentUser)
        return cell
    }
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isReadingHistory = !isTableViewNearBottom()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            isReadingHistory = !isTableViewNearBottom()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isReadingHistory = !isTableViewNearBottom()
    }
}

extension ChatViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        updateSendButtonState()

        let size = CGSize(width: textView.bounds.width, height: .infinity)
        let newHeight = ceil(textView.sizeThatFits(size).height)
        textView.isScrollEnabled = newHeight > 120
        let clampedHeight = min(newHeight, 120)
        textViewHeightConstraint?.constant = max(38, clampedHeight)
        view.layoutIfNeeded()
    }
}
