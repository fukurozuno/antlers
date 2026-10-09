import AppKit
import MafxCore

struct CommandPaletteCommandStatus {
    let isEnabled: Bool
    let detail: String
}

private final class CommandPaletteTableView: NSTableView {
    var onActivate: (() -> Void)?
    var onMove: ((Int) -> Void)?
    var onEscape: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            onActivate?()
        case AppKeyCode.upArrow:
            onMove?(-1)
        case AppKeyCode.downArrow:
            onMove?(1)
        case AppKeyCode.escape:
            onEscape?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class CommandPaletteRowView: NSTableRowView {
    var normalBackgroundColor: NSColor = .textBackgroundColor
    var selectedBackgroundColor: NSColor = .selectedContentBackgroundColor

    override func drawBackground(in dirtyRect: NSRect) {
        normalBackgroundColor.setFill()
        dirtyRect.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        selectedBackgroundColor.setFill()
        dirtyRect.fill()
    }
}

private final class CommandPalettePanel: NSPanel {
    var onEscape: (() -> Void)?

    override func cancelOperation(_ sender: Any?) { onEscape?() }
}

private final class CommandPaletteActionButton: NSButton {
    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if [AppKeyCode.returnKey, AppKeyCode.keypadEnter, AppKeyCode.space].contains(event.keyCode) {
            performClick(self)
        } else {
            super.keyDown(with: event)
        }
    }
}

/// 検索、履歴、実行の入口。ファイル操作そのものは呼び出し元のコマンド経路に委譲する。
final class CommandPalettePanelController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate,
    NSSearchFieldDelegate, NSWindowDelegate {
    var onExecute: ((CommandID) -> Void)?
    var onOpenKeybindings: ((CommandID) -> Void)?
    var onDismiss: (() -> Void)?

    private var items: [CommandPaletteItem] = []
    private var rows: [CommandPaletteRow] = []
    private var status: ((CommandID) -> CommandPaletteCommandStatus)?
    private let historyRepository = CommandPaletteHistoryRepository()
    private var history = CommandPaletteUsageHistory()
    private var theme: DisplayTheme = .light

    private let searchField = NSSearchField()
    private let tableView = CommandPaletteTableView()
    private let scrollView = NSScrollView()
    private let detailField = NSTextField(labelWithString: "")
    private let settingsButton = CommandPaletteActionButton()

    init() {
        let panel = CommandPalettePanel(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.string("commandPalette.title")
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 520, height: 320)
        super.init(window: panel)
        panel.delegate = self
        panel.onEscape = { [weak self] in self?.escape() }
        buildView(in: panel)
        tableView.onActivate = { [weak self] in self?.activateSelection() }
        tableView.onMove = { [weak self] delta in self?.moveSelection(by: delta) }
        tableView.onEscape = { [weak self] in self?.escape() }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(
        items: [CommandPaletteItem],
        theme: DisplayTheme,
        status: @escaping (CommandID) -> CommandPaletteCommandStatus,
        relativeTo parent: NSWindow?
    ) {
        self.items = items
        self.status = status
        history = historyRepository.load()
        searchField.stringValue = ""
        applyTheme(theme)
        updateResults()
        guard let window else { return }
        if let parent {
            window.setFrameOrigin(NSPoint(x: parent.frame.midX - window.frame.width / 2,
                                          y: parent.frame.midY - window.frame.height / 2))
        } else {
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(searchField)
    }

    func dismiss() {
        window?.orderOut(nil)
        onDismiss?()
    }

    func applyTheme(_ theme: DisplayTheme) {
        self.theme = theme
        let base = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let selected = theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false)
        let background = base.background?.paletteColor ?? .windowBackgroundColor
        let foreground = base.foreground?.paletteColor ?? .labelColor
        let selectedBackground = selected.background?.paletteColor ?? .selectedContentBackgroundColor
        let appearance = base.background.map { NSAppearance(named: $0.isDark ? .darkAqua : .aqua) } ?? nil

        window?.backgroundColor = background
        searchField.appearance = appearance
        scrollView.appearance = appearance
        searchField.backgroundColor = background
        searchField.textColor = foreground
        searchField.placeholderAttributedString = NSAttributedString(
            string: L10n.string("commandPalette.searchPlaceholder"),
            attributes: [.foregroundColor: foreground.withAlphaComponent(0.72)]
        )
        tableView.backgroundColor = background
        scrollView.backgroundColor = background
        detailField.textColor = foreground.withAlphaComponent(0.78)
        settingsButton.wantsLayer = true
        settingsButton.isBordered = false
        settingsButton.layer?.cornerRadius = 5
        settingsButton.layer?.backgroundColor = selectedBackground.cgColor
        updateSettingsButtonAppearance()
        tableView.reloadData()
        updateVisibleRowColors()
    }

    func windowWillClose(_ notification: Notification) { onDismiss?() }

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        rows.indices.contains(row) && rows[row].item != nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        rows[row].item == nil ? 26 : 44
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let rowView = CommandPaletteRowView()
        rowView.normalBackgroundColor = backgroundColor(isSelected: false)
        rowView.selectedBackgroundColor = backgroundColor(isSelected: true)
        return rowView
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let isBindingColumn = tableColumn?.identifier.rawValue == "binding"
        guard let item = rows[row].item else {
            let field = NSTextField(labelWithString: "")
            if !isBindingColumn, case .heading(let section) = rows[row] {
                field.stringValue = L10n.string(section == .recent ? "commandPalette.recent" : "commandPalette.all")
                field.font = .systemFont(ofSize: 11, weight: .semibold)
                field.textColor = foregroundColor(isSelected: false).withAlphaComponent(0.78)
            }
            return field
        }
        if isBindingColumn {
            let field = NSTextField(labelWithString: item.bindings.isEmpty
                ? L10n.string("commandPalette.unassigned") : item.bindings.joined(separator: " / "))
            field.lineBreakMode = .byTruncatingTail
            field.textColor = foregroundColor(isSelected: tableView.isRowSelected(row))
            field.toolTip = field.stringValue
            return field
        }
        let commandStatus = status?(item.commandID)
        let cell = NSView()
        let title = NSTextField(labelWithString: item.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        let foreground = foregroundColor(isSelected: tableView.isRowSelected(row))
        title.textColor = commandStatus?.isEnabled == false ? foreground.withAlphaComponent(0.55) : foreground
        title.lineBreakMode = .byTruncatingTail
        title.translatesAutoresizingMaskIntoConstraints = false
        let detail = NSTextField(labelWithString: detailText(for: item))
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = foreground.withAlphaComponent(0.78)
        detail.lineBreakMode = .byTruncatingTail
        detail.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)
        cell.addSubview(detail)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),
            title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 3),
            title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -3),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor)
        ])
        cell.toolTip = "\(item.title) — \(detailText(for: item))"
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateVisibleRowColors()
        updateDetail()
    }

    func controlTextDidChange(_ obj: Notification) {
        updateResults()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
        case #selector(NSResponder.insertNewline(_:)):
            activateSelection()
        case #selector(NSResponder.cancelOperation(_:)):
            escape()
        default:
            return false
        }
        return true
    }

    private func buildView(in panel: NSPanel) {
        guard let content = panel.contentView else { return }
        searchField.placeholderString = L10n.string("commandPalette.searchPlaceholder")
        searchField.setAccessibilityLabel(L10n.string("commandPalette.searchPlaceholder"))
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        tableView.headerView = nil
        tableView.setAccessibilityLabel(L10n.string("commandPalette.title"))
        tableView.rowHeight = 44
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(activateSelectionFromDoubleClick)
        let commandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        commandColumn.width = 390
        tableView.addTableColumn(commandColumn)
        let bindingColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("binding"))
        bindingColumn.width = 205
        bindingColumn.minWidth = 120
        tableView.addTableColumn(bindingColumn)
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        detailField.textColor = .secondaryLabelColor
        detailField.lineBreakMode = .byWordWrapping
        detailField.maximumNumberOfLines = 2
        detailField.translatesAutoresizingMaskIntoConstraints = false

        settingsButton.title = L10n.string("commandPalette.openKeybindings")
        settingsButton.target = self
        settingsButton.action = #selector(openKeybindings)
        let actionRow = NSStackView(views: [settingsButton])
        actionRow.spacing = 8
        actionRow.translatesAutoresizingMaskIntoConstraints = false

        for view in [searchField, scrollView, detailField, actionRow] { content.addSubview(view) }
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            detailField.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            detailField.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            detailField.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            detailField.heightAnchor.constraint(equalToConstant: 38),
            actionRow.topAnchor.constraint(equalTo: detailField.bottomAnchor, constant: 8),
            actionRow.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            actionRow.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12)
        ])
        searchField.nextKeyView = tableView
        tableView.nextKeyView = settingsButton
        settingsButton.nextKeyView = searchField
    }

    private func updateResults() {
        rows = CommandPaletteList.rows(for: searchField.stringValue, in: items, history: history)
        tableView.reloadData()
        if let first = rows.firstIndex(where: { $0.item != nil }) {
            tableView.selectRowIndexes(IndexSet(integer: first), byExtendingSelection: false)
            tableView.scrollRowToVisible(first)
        } else {
            tableView.deselectAll(nil)
        }
        updateDetail()
    }

    private var selectedItem: CommandPaletteItem? {
        guard rows.indices.contains(tableView.selectedRow) else { return nil }
        return rows[tableView.selectedRow].item
    }

    private func detailText(for item: CommandPaletteItem) -> String {
        let description = status?(item.commandID).detail ?? ""
        var english = item.englishTitle.map { [$0] } ?? []
        for match in CommandPaletteSearch.englishMatchExplanation(for: searchField.stringValue, in: item)
            where !english.contains(match) {
            english.append(match)
        }
        guard !english.isEmpty else { return description }
        return "\(english.joined(separator: " / "))  ·  \(description)"
    }

    private func updateDetail() {
        guard let item = selectedItem else {
            detailField.stringValue = L10n.string("commandPalette.noResults")
            settingsButton.isEnabled = false
            updateSettingsButtonAppearance()
            return
        }
        let bindingText = item.bindings.joined(separator: " / ")
        let description = detailText(for: item)
        detailField.stringValue = bindingText.isEmpty ? description : "\(description)  ·  \(bindingText)"
        settingsButton.isEnabled = true
        updateSettingsButtonAppearance()
    }

    private func updateSettingsButtonAppearance() {
        let selected = theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false)
        let foreground = selected.foreground?.paletteColor ?? .selectedMenuItemTextColor
        settingsButton.attributedTitle = NSAttributedString(
            string: L10n.string("commandPalette.openKeybindings"),
            attributes: [.foregroundColor: foreground.withAlphaComponent(settingsButton.isEnabled ? 1 : 0.55)]
        )
    }

    private func backgroundColor(isSelected: Bool) -> NSColor {
        theme.resolvedColorPair(isSelected: isSelected, isMarked: false, isDirectory: false)
            .background?.paletteColor ?? (isSelected ? .selectedContentBackgroundColor : .windowBackgroundColor)
    }

    private func foregroundColor(isSelected: Bool) -> NSColor {
        theme.resolvedColorPair(isSelected: isSelected, isMarked: false, isDirectory: false)
            .foreground?.paletteColor ?? (isSelected ? .selectedMenuItemTextColor : .labelColor)
    }

    private func updateVisibleRowColors() {
        let visibleRows = tableView.rows(in: tableView.visibleRect)
        guard visibleRows.length > 0 else { return }
        for row in visibleRows.location..<NSMaxRange(visibleRows) where rows.indices.contains(row) {
            let foreground = foregroundColor(isSelected: tableView.isRowSelected(row))
            if let field = tableView.view(atColumn: 1, row: row, makeIfNecessary: false) as? NSTextField {
                field.textColor = foreground
            }
            guard let cell = tableView.view(atColumn: 0, row: row, makeIfNecessary: false) else { continue }
            if let heading = cell as? NSTextField {
                heading.textColor = foreground.withAlphaComponent(0.78)
                continue
            }
            let labels = cell.subviews.compactMap { $0 as? NSTextField }
            if let title = labels.first, let item = rows[row].item {
                title.textColor = status?(item.commandID).isEnabled == false
                    ? foreground.withAlphaComponent(0.55) : foreground
            }
            if labels.count > 1 {
                labels[1].textColor = foreground.withAlphaComponent(0.78)
            }
        }
    }

    private func moveSelection(by delta: Int) {
        guard let next = CommandPaletteList.selection(in: rows, from: tableView.selectedRow, moving: delta) else { return }
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func activateSelection() {
        guard let item = selectedItem, status?(item.commandID).isEnabled == true else { return }
        // 確認画面のキャンセルや処理結果によらず、パレットで実行を選んだ時点で記録する。
        history.record(item.commandID)
        historyRepository.save(history)
        dismiss()
        onExecute?(item.commandID)
    }

    private func escape() { dismiss() }

    @objc private func activateSelectionFromDoubleClick() {
        guard rows.indices.contains(tableView.clickedRow), rows[tableView.clickedRow].item != nil else { return }
        activateSelection()
    }

    @objc private func openKeybindings() {
        guard let item = selectedItem else { return }
        dismiss()
        onOpenKeybindings?(item.commandID)
    }
}

private extension DisplayColor {
    var paletteColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    var isDark: Bool {
        0.2126 * red + 0.7152 * green + 0.0722 * blue < 0.5
    }
}
