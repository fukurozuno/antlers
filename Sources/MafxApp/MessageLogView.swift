import AppKit
import MafxCore

final class MessageLogView: NSView {
    private let titleLabel = NSTextField(labelWithString: L10n.string("messageLog.title"))
    private let textView = MessageTextView()
    private let scrollView = NSScrollView()
    private var renderedMessages: [String]?
    private var renderedTransientMessage: String?
    private var renderedTheme: DisplayTheme?
    private var renderedTitle: String?

    override var acceptsFirstResponder: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(messages: [String], transientMessage: String? = nil, theme: DisplayTheme = .light) {
        let title = L10n.string("messageLog.title")
        if renderedTheme != theme {
            applyTheme(theme)
            renderedTheme = theme
        }
        if renderedTitle != title {
            titleLabel.stringValue = title
            renderedTitle = title
        }
        guard renderedMessages != messages || renderedTransientMessage != transientMessage else {
            return
        }

        let displayedMessages = messages + (transientMessage.map { [$0] } ?? [])
        textView.string = displayedMessages.joined(separator: "\n")
        renderedMessages = messages
        renderedTransientMessage = transientMessage
        scrollToBottom()
    }

    private func applyTheme(_ theme: DisplayTheme) {
        let backgroundColor: NSColor
        if let messageBackground = theme.message.background {
            backgroundColor = messageBackground.transparentNSColor
        } else {
            backgroundColor = theme.base.background?.nsColor ?? .textBackgroundColor
        }
        let colors = theme.resolvedMessageColorPair
        let foregroundColor = colors.foreground?.nsColor ?? .labelColor

        layer?.backgroundColor = backgroundColor.cgColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.textColor = foregroundColor
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        textView.backgroundColor = .clear
        textView.textColor = foregroundColor
    }

    private func buildView() {
        wantsLayer = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = .boldSystemFont(ofSize: 12)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.textContainerInset = NSSize(width: 8, height: 6)

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 6),

            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func scrollToBottom() {
        guard !textView.string.isEmpty else {
            return
        }

        let textLength = (textView.string as NSString).length
        textView.scrollRangeToVisible(NSRange(location: textLength, length: 0))
    }
}

private extension DisplayColor {
    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }

    var transparentNSColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(paneBackgroundAlpha)
        )
    }
}

private final class MessageTextView: NSTextView {
    override var acceptsFirstResponder: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(nextResponder)
    }
}
