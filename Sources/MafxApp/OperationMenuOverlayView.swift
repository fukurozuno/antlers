import AppKit
import MafxCore

struct OperationMenuEntry {
    let title: String
    let commandID: CommandID?
    let isEnabled: Bool
    let image: NSImage?
    let children: [OperationMenuEntry]
    let action: (() -> Void)?

    init(
        title: String,
        commandID: CommandID? = nil,
        isEnabled: Bool = true,
        image: NSImage? = nil,
        children: [OperationMenuEntry] = [],
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.commandID = commandID
        self.isEnabled = isEnabled
        self.image = image
        self.children = children
        self.action = action
    }
}

/// 操作メニューをメインウィンドウから分離して表示する影付きパネルです。
final class OperationMenuPanelController: NSWindowController {
    init() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = true
        panel.collectionBehavior = [.auxiliary, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present(contentView: NSView, size: NSSize, relativeTo mainWindow: NSWindow?) {
        guard let window else { return }
        window.contentView = contentView
        window.setContentSize(size)

        if let mainWindow {
            let frame = mainWindow.frame
            window.setFrameOrigin(NSPoint(
                x: frame.midX - window.frame.width / 2,
                y: frame.midY - window.frame.height / 2
            ))
        } else {
            window.center()
        }
        window.orderFront(nil)
    }

    func dismiss() {
        window?.orderOut(nil)
    }
}

/// `/` で表示する、キー操作とクリックの両方を受け付ける操作一覧です。
/// キー入力は親の DualPaneViewController が解決し、このビューは表示とクリックだけを担います。
final class OperationMenuOverlayView: NSView {
    private let card = NSView()
    private let stackView = NSStackView()
    private let keyBindingSet: KeyBindingSet
    private let theme: DisplayTheme
    private var entryStack: [[OperationMenuEntry]] = []
    private var selectedIndex = 0

    var onEntryActivated: ((OperationMenuEntry) -> Void)?
    var onContentSizeChange: ((NSSize) -> Void)?

    var currentEntries: [OperationMenuEntry] {
        entryStack.last ?? []
    }

    var preferredContentSize: NSSize {
        let rowCount = CGFloat(currentEntries.count)
        return NSSize(width: 420, height: rowCount * 30 + max(0, rowCount - 1) * 2 + 20)
    }

    init(entries: [OperationMenuEntry], keyBindingSet: KeyBindingSet, theme: DisplayTheme) {
        self.keyBindingSet = keyBindingSet
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let colors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        card.wantsLayer = true
        card.layer?.backgroundColor = colors.background.map(opaqueNSColor)?.cgColor
        card.layer?.cornerRadius = 10
        card.translatesAutoresizingMaskIntoConstraints = false

        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 2
        stackView.edgeInsets = NSEdgeInsets(top: 10, left: 14, bottom: 10, right: 22)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(card)
        card.addSubview(stackView)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 420),
            stackView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -32),
            stackView.topAnchor.constraint(equalTo: card.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])

        entryStack = [entries]
        rebuildRows()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func moveSelection(by delta: Int) {
        let enabledIndices = currentEntries.indices.filter { currentEntries[$0].isEnabled }
        guard !enabledIndices.isEmpty else { return }
        let currentPosition = enabledIndices.firstIndex(of: selectedIndex) ?? 0
        selectedIndex = enabledIndices[(currentPosition + delta + enabledIndices.count) % enabledIndices.count]
        rebuildRows()
    }

    func activateSelection() {
        guard currentEntries.indices.contains(selectedIndex) else { return }
        activate(currentEntries[selectedIndex])
    }

    func goBack() -> Bool {
        guard entryStack.count > 1 else { return false }
        entryStack.removeLast()
        selectedIndex = firstEnabledIndex()
        rebuildRows()
        return true
    }

    func showChildEntries(_ entries: [OperationMenuEntry]) {
        entryStack.append(entries)
        selectedIndex = firstEnabledIndex()
        rebuildRows()
    }

    /// アプリケーション選択のような子一覧で、先頭文字に一致する項目へ移動します。
    func focusFirstEnabledEntry(startingWith prefix: String) -> Bool {
        let normalizedPrefix = normalizedForInitialSelection(prefix)
        guard !normalizedPrefix.isEmpty,
              let index = currentEntries.firstIndex(where: {
                  $0.isEnabled && normalizedForInitialSelection($0.title).hasPrefix(normalizedPrefix)
              }) else {
            return false
        }

        selectedIndex = index
        rebuildRows()
        return true
    }

    func entry(for commandID: CommandID) -> OperationMenuEntry? {
        currentEntries.first { $0.commandID == commandID && $0.isEnabled }
    }

    /// 操作名の右側に表示する、現在有効な最初のキーバインドです。
    /// 子一覧を開く項目も、他の項目と同じくキーバインドを優先して表示します。
    func shortcutDisplayText(for entry: OperationMenuEntry) -> String {
        entry.commandID.flatMap { keyBindingSet.sequences(for: $0).first?.displayText } ?? ""
    }

    private func activate(_ entry: OperationMenuEntry) {
        guard entry.isEnabled else { return }
        if !entry.children.isEmpty {
            entryStack.append(entry.children)
            selectedIndex = firstEnabledIndex()
            rebuildRows()
            return
        }
        onEntryActivated?(entry)
    }

    private func firstEnabledIndex() -> Int {
        currentEntries.firstIndex { $0.isEnabled } ?? 0
    }

    private func normalizedForInitialSelection(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
    }

    private func rebuildRows() {
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for (index, entry) in currentEntries.enumerated() {
            let shortcut = shortcutDisplayText(for: entry)
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            row.translatesAutoresizingMaskIntoConstraints = false

            let button = NSButton(title: entry.title, target: self, action: #selector(rowClicked(_:)))
            button.tag = index
            button.alignment = .left
            button.isBordered = false
            button.isEnabled = entry.isEnabled
            button.state = index == selectedIndex ? .on : .off
            button.setButtonType(.toggle)
            let rowColors = theme.resolvedColorPair(
                isSelected: index == selectedIndex,
                isMarked: false,
                isDirectory: false
            )
            let titleParagraphStyle = NSMutableParagraphStyle()
            titleParagraphStyle.alignment = .left
            titleParagraphStyle.firstLineHeadIndent = 6
            titleParagraphStyle.headIndent = 6
            button.attributedTitle = NSAttributedString(
                string: entry.title,
                attributes: [
                    .foregroundColor: rowColors.foreground.map(opaqueNSColor) ?? .labelColor,
                    .paragraphStyle: titleParagraphStyle
                ]
            )
            button.wantsLayer = true
            button.layer?.cornerRadius = 8
            button.layer?.backgroundColor = (index == selectedIndex ? rowColors.background : baseColors.background)
                .map(opaqueNSColor)?.cgColor
            button.translatesAutoresizingMaskIntoConstraints = false
            if let image = entry.image {
                let imageView = NSImageView(image: image)
                imageView.imageScaling = .scaleProportionallyDown
                imageView.translatesAutoresizingMaskIntoConstraints = false
                row.addArrangedSubview(imageView)
                imageView.widthAnchor.constraint(equalToConstant: 20).isActive = true
                imageView.heightAnchor.constraint(equalToConstant: 20).isActive = true
            }
            let shortcutLabel = NSTextField(labelWithString: shortcut)
            shortcutLabel.alignment = .right
            shortcutLabel.textColor = entry.isEnabled
                ? (rowColors.foreground.map(opaqueNSColor) ?? .secondaryLabelColor)
                : .disabledControlTextColor
            shortcutLabel.font = .monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            shortcutLabel.translatesAutoresizingMaskIntoConstraints = false
            row.addArrangedSubview(button)
            row.addArrangedSubview(shortcutLabel)
            button.widthAnchor.constraint(equalTo: row.widthAnchor, constant: entry.image == nil ? -108 : -136).isActive = true
            shortcutLabel.widthAnchor.constraint(equalToConstant: 100).isActive = true
            stackView.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }
        onContentSizeChange?(preferredContentSize)
    }

    @objc private func rowClicked(_ sender: NSButton) {
        guard currentEntries.indices.contains(sender.tag) else { return }
        selectedIndex = sender.tag
        activate(currentEntries[sender.tag])
    }
}

private func opaqueNSColor(_ color: DisplayColor) -> NSColor {
    NSColor(calibratedRed: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue), alpha: 1)
}
