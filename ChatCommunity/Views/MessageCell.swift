import UIKit

final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let bubbleView = UIView()
    private let authorLabel = UILabel()
    private let messageLabel = UILabel()
    private let timestampLabel = UILabel()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        configureViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureViews() {
        bubbleView.layer.cornerRadius = 16
        bubbleView.translatesAutoresizingMaskIntoConstraints = false

        authorLabel.font = UIFont.preferredFont(forTextStyle: .caption1)
        authorLabel.textColor = .secondaryLabel

        messageLabel.numberOfLines = 0
        messageLabel.font = UIFont.preferredFont(forTextStyle: .body)

        timestampLabel.font = UIFont.preferredFont(forTextStyle: .caption2)
        timestampLabel.textColor = .tertiaryLabel

        let stack = UIStackView(arrangedSubviews: [authorLabel, messageLabel, timestampLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false

        bubbleView.addSubview(stack)
        contentView.addSubview(bubbleView)

        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            stack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),

            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)
        ])
    }

    func configure(with message: Message, isCurrentUser: Bool) {
        authorLabel.text = message.author
        let displayText = message.content.isEmpty ? "…" : message.content
        messageLabel.text = displayText
        timestampLabel.text = message.isComplete ? message.timestampFormatted : "生成中..."

        if isCurrentUser {
            bubbleView.backgroundColor = tintColor
            messageLabel.textColor = .white
            authorLabel.textColor = UIColor(white: 1, alpha: 0.9)
            timestampLabel.textColor = UIColor(white: 1, alpha: 0.9)
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = UIColor.secondarySystemBackground
            messageLabel.textColor = .label
            authorLabel.textColor = .secondaryLabel
            timestampLabel.textColor = .tertiaryLabel
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
        layoutIfNeeded()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        leadingConstraint.isActive = false
        trailingConstraint.isActive = false
    }
}
