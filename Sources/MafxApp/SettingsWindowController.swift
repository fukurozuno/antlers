import AppKit
import MafxCore
import UniformTypeIdentifiers

func canApplyKeyBindingSet(_ keyBindingSet: KeyBindingSet) -> Bool {
    keyBindingSet.conflicts().isEmpty
}

enum SettingsListEditorValue: Equatable {
    case bookmark(displayName: String, path: String)
    case fileType(extensions: String, isOtherExtensions: Bool, applicationPath: String, color: DisplayColor?)
}

func hasUnappliedSettingsListEditorChanges(
    current: SettingsListEditorValue?,
    applied: SettingsListEditorValue?
) -> Bool {
    current != nil && current != applied
}

final class SettingsWindowController: NSWindowController {
    private let settingsViewController: SettingsViewController
    private weak var presentingWindow: NSWindow?

    init(settings: SettingsState = SettingsState()) {
        settingsViewController = SettingsViewController(settings: settings)
        let window = NSWindow(contentViewController: settingsViewController)

        window.title = L10n.string("settings.window.title")
        window.setContentSize(NSSize(width: 820, height: 560))
        window.minSize = NSSize(width: 760, height: 480)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = settingsViewController

        super.init(window: window)
        settingsViewController.onDismiss = { [weak self] in
            self?.dismissSheet()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func presentAsSheet(for parentWindow: NSWindow, focusedCommandID: CommandID? = nil) {
        guard let window else {
            return
        }

        guard window.sheetParent == nil else {
            window.makeKeyAndOrderFront(nil)
            return
        }

        settingsViewController.prepareForPresentation(focusedCommandID: focusedCommandID)
        presentingWindow = parentWindow
        parentWindow.beginSheet(window)
    }

    private func dismissSheet() {
        guard let window else {
            return
        }

        let parentWindow = window.sheetParent ?? presentingWindow
        presentingWindow = nil
        settingsViewController.didDismiss()

        if let parentWindow {
            parentWindow.endSheet(window)
        }
        window.orderOut(nil)
    }
}

private final class SettingsViewController: NSViewController, NSWindowDelegate, NSSearchFieldDelegate {
    var onDismiss: (() -> Void)?

    private var committedState: SettingsState
    private var state: SettingsState
    private let segmentedControl = SettingsTabSegmentedControl(labels: SettingsState.defaultTabs.map(\.localizedTitle))
    private let tableView = SettingsTableView()
    private let scrollView = NSScrollView()
    private let okButton = NSButton(title: L10n.string("settings.button.ok"), target: nil, action: nil)
    private let cancelButton = NSButton(title: L10n.string("settings.button.cancel"), target: nil, action: nil)
    private let importSettingsButton = NSButton(title: L10n.string("settings.button.importSettings"), target: nil, action: nil)
    private let importSelectedSettingsButton = NSButton(title: "", target: nil, action: nil)
    private let exportSettingsButton = NSButton(title: L10n.string("settings.button.exportSettings"), target: nil, action: nil)
    private let pathNameField = NSTextField(string: "")
    private let pathField = NSTextField(string: "")
    private let addPathButton = NSButton(title: L10n.string("settings.button.add"), target: nil, action: nil)
    private let updatePathButton = NSButton(title: L10n.string("settings.button.update"), target: nil, action: nil)
    private let deletePathButton = NSButton(title: L10n.string("settings.button.delete"), target: nil, action: nil)
    private let movePathUpButton = NSButton(title: L10n.string("settings.button.moveUp"), target: nil, action: nil)
    private let movePathDownButton = NSButton(title: L10n.string("settings.button.moveDown"), target: nil, action: nil)
    private let pathButtonRow = NSView()
    private let keyBindingStatusField = NSTextField(labelWithString: "")
    private let keyBindingSearchField = NSSearchField()
    private let keyBindingSearchButton = NSButton(title: "", target: nil, action: nil)
    private let keyBindingClearSearchButton = NSButton(title: "", target: nil, action: nil)
    private let keyBindingSearchRow = NSStackView()
    private let keyBindingCaptureView = KeyBindingCaptureView()
    private let keyBindingDetailLabel = NSTextField(labelWithString: "")
    private let keyBindingDetailTable = NSTableView()
    private let keyBindingDetailScrollView = NSScrollView()
    private let keyBindingDetailDataSource = KeyBindingDetailDataSource()
    private let recordKeyBindingButton = NSButton(title: L10n.string("settings.button.recordBinding"), target: nil, action: nil)
    private let keyBindingMoreButton = NSPopUpButton(frame: .zero, pullsDown: true)
    private let keyBindingKeyActionRow = NSStackView()
    private let keyBindingKeyAssignButton = NSButton(title: "", target: nil, action: nil)
    private let keyBindingKeyRemoveButton = NSButton(title: "", target: nil, action: nil)
    private let keyBindingButtonRow = NSView()
    private let themePopupButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let addThemeButton = NSButton(title: L10n.string("settings.button.duplicateCurrentTheme"), target: nil, action: nil)
    private let deleteThemeButton = NSButton(title: L10n.string("settings.button.deleteCurrentTheme"), target: nil, action: nil)
    private let usesBackgroundColorButton = NSButton(checkboxWithTitle: L10n.string("settings.checkbox.useBackgroundColor"), target: nil, action: nil)
    private let backgroundColorWell = NSColorWell()
    private let backgroundAlphaLabel = NSTextField(labelWithString: "")
    private let backgroundAlphaSlider = NSSlider(
        value: 100,
        minValue: DisplayColor.minimumPaneBackgroundAlpha * 100,
        maxValue: 100,
        target: nil,
        action: nil
    )
    private let backgroundAlphaRow = NSStackView()
    private let usesForegroundColorButton = NSButton(checkboxWithTitle: L10n.string("settings.checkbox.useForegroundColor"), target: nil, action: nil)
    private let foregroundColorWell = NSColorWell()
    private let appearanceEditorStack = NSStackView()
    private let themePreviewView = ThemePreviewView()
    private let pathEditorStack = NSStackView()
    private let fileTypeExtensionsField = NSTextField(string: "")
    private let fileTypeOtherExtensionsButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fileTypeApplicationField = NSTextField(string: "")
    private let chooseFileTypeApplicationButton = NSButton(title: "", target: nil, action: nil)
    private let fileTypeUsesColorButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let fileTypeColorWell = NSColorWell()
    private let fileTypeColorScopeLabel = NSTextField(labelWithString: "")
    private let fileTypeColorScopePopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let portableSettingsService = PortableSettingsJSONService()
    private let dataSource = SettingsDataSource()
    private var pathEditorHeightConstraint: NSLayoutConstraint?
    private var scrollViewNormalTrailingConstraint: NSLayoutConstraint?
    private var scrollViewThemeTrailingConstraint: NSLayoutConstraint?
    private var exportSettingsNormalLeadingConstraint: NSLayoutConstraint?
    private var exportSettingsPartialLeadingConstraint: NSLayoutConstraint?
    private var recordingCommandID: CommandID?
    private var recordedKeyStrokes: [KeyStroke] = []
    private var searchedKeyStrokes: [KeyStroke] = []
    private var isCapturingKeySearch = false
    private var keyBindingSearchHeightConstraint: NSLayoutConstraint?
    private var keyBindingCaptureHeightConstraint: NSLayoutConstraint?
    private var keyBindingDetailHeightConstraint: NSLayoutConstraint?
    private var captureDisabledControlStates: [(NSControl, Bool)] = []
    private var closeButtonWasEnabled: Bool?
    private var miniaturizeButtonWasEnabled: Bool?
    private var isRendering = false
    private var isClosingAfterCommit = false

    init(settings: SettingsState = SettingsState()) {
        committedState = settings
        state = settings
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jumpPathEntriesDidChange(_:)),
            name: .jumpPathEntriesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: .settingsDidChange,
            object: nil
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        segmentedControl.target = self
        segmentedControl.action = #selector(tabSelectionChanged(_:))
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.onMoveTabSelection = { [weak self] delta in
            self?.moveTabSelection(by: delta)
        }
        segmentedControl.onMoveToItems = { [weak self] in
            self?.focusItems()
        }
        segmentedControl.onCommit = { [weak self] in
            self?.saveAndClose()
        }
        segmentedControl.onCancel = { [weak self] in
            self?.discardAndClose()
        }

        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.target = self
        tableView.action = #selector(commandTableClicked(_:))
        tableView.doubleAction = #selector(tableViewDoubleClicked(_:))
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .regular
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .textBackgroundColor
        tableView.onMoveItemFocus = { [weak self] delta in
            self?.moveItemFocus(by: delta)
        }
        tableView.onMoveFocusedItem = { [weak self] delta in
            self?.moveSelectedPath(by: delta)
        }
        tableView.onToggleFocusedItem = { [weak self] in
            self?.toggleFocusedItem()
        }
        tableView.onCommit = { [weak self] in
            self?.saveAndClose()
        }
        tableView.onCancel = { [weak self] in
            self?.discardAndClose()
        }
        tableView.onDeleteFocusedItem = { [weak self] in
            self?.deleteFocusedItem()
        }
        tableView.onRecordKeyBindingStroke = { [weak self] stroke in
            self?.recordKeyBindingStroke(stroke)
        }
        tableView.onCommitRecordedKeyBinding = { [weak self] in
            self?.commitRecordedKeyBinding()
        }
        tableView.onCancelRecordedKeyBinding = { [weak self] in
            self?.cancelRecordedKeyBinding()
        }
        dataSource.onSelectionChange = { [weak self] row in
            self?.focusItem(at: row)
        }
        dataSource.onToggleItem = { [weak self] row in
            guard row >= 0 else {
                return
            }

            self?.focusItem(at: row)
            self?.toggleFocusedItem()
        }
        dataSource.onChoiceChange = { [weak self] row, value in
            guard row >= 0 else {
                return
            }

            self?.focusItem(at: row)
            self?.setChoiceForFocusedItem(value)
        }
        dataSource.onStartupPathChange = { [weak self] row, path in
            self?.setStartupPath(path, forItemAt: row)
        }
        dataSource.onNumericValueChange = { [weak self] row, value in
            self?.setNumericValue(value, forItemAt: row)
        }

        let settingColumn = NSTableColumn(identifier: SettingsDataSource.Column.setting)
        settingColumn.title = L10n.string("settings.column.setting")
        settingColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(settingColumn)

        pathNameField.placeholderString = L10n.string("settings.placeholder.displayName")
        pathField.placeholderString = L10n.string("settings.placeholder.path")
        pathNameField.translatesAutoresizingMaskIntoConstraints = false
        pathField.translatesAutoresizingMaskIntoConstraints = false

        addPathButton.target = self
        addPathButton.action = #selector(addPathButtonClicked(_:))
        updatePathButton.target = self
        updatePathButton.action = #selector(updatePathButtonClicked(_:))
        deletePathButton.target = self
        deletePathButton.action = #selector(deletePathButtonClicked(_:))
        movePathUpButton.target = self
        movePathUpButton.action = #selector(movePathUpButtonClicked(_:))
        movePathDownButton.target = self
        movePathDownButton.action = #selector(movePathDownButtonClicked(_:))
        recordKeyBindingButton.target = self
        recordKeyBindingButton.action = #selector(recordKeyBindingButtonClicked(_:))
        keyBindingMoreButton.addItems(withTitles: ["⋯", L10n.string("settings.button.resetCommand"),
                                                   L10n.string("settings.button.resetAll")])
        keyBindingMoreButton.item(at: 1)?.target = self
        keyBindingMoreButton.item(at: 1)?.action = #selector(resetCommandMenuItemSelected(_:))
        keyBindingMoreButton.item(at: 2)?.target = self
        keyBindingMoreButton.item(at: 2)?.action = #selector(resetAllMenuItemSelected(_:))
        keyBindingKeyAssignButton.target = self
        keyBindingKeyAssignButton.action = #selector(assignSearchedKeyButtonClicked(_:))
        keyBindingKeyRemoveButton.target = self
        keyBindingKeyRemoveButton.action = #selector(removeSearchedKeyButtonClicked(_:))
        keyBindingSearchField.delegate = self
        keyBindingSearchField.translatesAutoresizingMaskIntoConstraints = false
        keyBindingSearchButton.target = self
        keyBindingSearchButton.action = #selector(searchKeyBindingButtonClicked(_:))
        keyBindingClearSearchButton.target = self
        keyBindingClearSearchButton.action = #selector(clearKeyBindingSearchButtonClicked(_:))
        keyBindingSearchRow.orientation = .horizontal
        keyBindingSearchRow.spacing = 8
        keyBindingSearchRow.translatesAutoresizingMaskIntoConstraints = false
        keyBindingSearchRow.addArrangedSubview(keyBindingSearchField)
        keyBindingSearchRow.addArrangedSubview(keyBindingSearchButton)
        keyBindingSearchRow.addArrangedSubview(keyBindingClearSearchButton)
        keyBindingCaptureView.onStroke = { [weak self] stroke in
            guard let self else { return }
            if self.recordingCommandID != nil {
                self.recordKeyBindingStroke(stroke)
            } else {
                self.searchKeyBindingStroke(stroke)
            }
        }
        keyBindingCaptureView.onFinish = { [weak self] in
            guard let self else { return }
            if self.recordingCommandID != nil {
                self.commitRecordedKeyBinding()
            } else {
                self.view.window?.makeFirstResponder(self.keyBindingCaptureView)
            }
        }
        keyBindingCaptureView.onCancel = { [weak self] in
            guard let self else { return }
            if self.recordingCommandID != nil {
                self.cancelRecordedKeyBinding()
                self.render()
                self.view.window?.makeFirstResponder(self.tableView)
            } else {
                self.clearKeyBindingSearch()
            }
        }
        keyBindingCaptureView.translatesAutoresizingMaskIntoConstraints = false
        keyBindingCaptureView.isHidden = true

        keyBindingDetailLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        keyBindingDetailTable.headerView = nil
        keyBindingDetailTable.rowHeight = 24
        keyBindingDetailTable.intercellSpacing = .zero
        keyBindingDetailTable.setAccessibilityLabel(L10n.string("settings.keybinding.details"))
        let detailColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("binding"))
        detailColumn.resizingMask = .autoresizingMask
        keyBindingDetailTable.addTableColumn(detailColumn)
        keyBindingDetailTable.dataSource = keyBindingDetailDataSource
        keyBindingDetailTable.delegate = keyBindingDetailDataSource
        keyBindingDetailDataSource.onRemoveSequence = { [weak self] index in
            self?.removeKeyBindingSequence(at: index)
        }
        keyBindingDetailTable.allowsEmptySelection = true
        keyBindingDetailTable.target = self
        keyBindingDetailScrollView.documentView = keyBindingDetailTable
        keyBindingDetailScrollView.hasVerticalScroller = true
        keyBindingDetailScrollView.borderType = .bezelBorder
        keyBindingDetailScrollView.translatesAutoresizingMaskIntoConstraints = false
        themePopupButton.target = self
        themePopupButton.action = #selector(themePopupChanged(_:))
        addThemeButton.target = self
        addThemeButton.action = #selector(addThemeButtonClicked(_:))
        deleteThemeButton.target = self
        deleteThemeButton.action = #selector(deleteThemeButtonClicked(_:))
        usesBackgroundColorButton.target = self
        usesBackgroundColorButton.action = #selector(backgroundColorEditorChanged(_:))
        backgroundColorWell.target = self
        backgroundColorWell.action = #selector(backgroundColorEditorChanged(_:))
        backgroundAlphaSlider.target = self
        backgroundAlphaSlider.action = #selector(backgroundAlphaEditorChanged(_:))
        usesForegroundColorButton.target = self
        usesForegroundColorButton.action = #selector(foregroundColorEditorChanged(_:))
        foregroundColorWell.target = self
        foregroundColorWell.action = #selector(foregroundColorEditorChanged(_:))
        chooseFileTypeApplicationButton.target = self
        chooseFileTypeApplicationButton.action = #selector(chooseFileTypeApplication(_:))
        fileTypeUsesColorButton.target = self
        fileTypeUsesColorButton.action = #selector(fileTypeColorChanged(_:))
        fileTypeOtherExtensionsButton.target = self
        fileTypeOtherExtensionsButton.action = #selector(fileTypeOtherExtensionsChanged(_:))
        fileTypeColorWell.target = self
        fileTypeColorWell.action = #selector(fileTypeColorChanged(_:))
        fileTypeColorScopePopup.target = self
        fileTypeColorScopePopup.action = #selector(fileTypeColorScopeChanged(_:))

        let pathFieldStack = NSStackView(views: [pathNameField, pathField])
        pathFieldStack.orientation = .vertical
        pathFieldStack.spacing = 6
        pathFieldStack.translatesAutoresizingMaskIntoConstraints = false

        pathEditorStack.orientation = .vertical
        pathEditorStack.spacing = 8
        pathEditorStack.translatesAutoresizingMaskIntoConstraints = false

        fileTypeOtherExtensionsButton.translatesAutoresizingMaskIntoConstraints = false

        pathEditorStack.addArrangedSubview(pathFieldStack)

        addPathButton.translatesAutoresizingMaskIntoConstraints = false
        updatePathButton.translatesAutoresizingMaskIntoConstraints = false
        deletePathButton.translatesAutoresizingMaskIntoConstraints = false
        movePathUpButton.translatesAutoresizingMaskIntoConstraints = false
        movePathDownButton.translatesAutoresizingMaskIntoConstraints = false
        pathButtonRow.translatesAutoresizingMaskIntoConstraints = false
        pathButtonRow.addSubview(movePathUpButton)
        pathButtonRow.addSubview(movePathDownButton)
        pathButtonRow.addSubview(addPathButton)
        pathButtonRow.addSubview(updatePathButton)
        pathButtonRow.addSubview(deletePathButton)
        pathEditorStack.addArrangedSubview(pathButtonRow)

        keyBindingStatusField.font = .systemFont(ofSize: 12)
        keyBindingStatusField.textColor = .secondaryLabelColor
        keyBindingStatusField.lineBreakMode = .byTruncatingTail
        keyBindingStatusField.translatesAutoresizingMaskIntoConstraints = false
        keyBindingDetailLabel.translatesAutoresizingMaskIntoConstraints = false
        pathEditorStack.addArrangedSubview(keyBindingDetailLabel)
        pathEditorStack.addArrangedSubview(keyBindingDetailScrollView)
        recordKeyBindingButton.translatesAutoresizingMaskIntoConstraints = false
        keyBindingMoreButton.translatesAutoresizingMaskIntoConstraints = false
        keyBindingKeyActionRow.orientation = .horizontal
        keyBindingKeyActionRow.spacing = 8
        keyBindingKeyActionRow.translatesAutoresizingMaskIntoConstraints = false
        keyBindingKeyAssignButton.translatesAutoresizingMaskIntoConstraints = false
        keyBindingKeyRemoveButton.translatesAutoresizingMaskIntoConstraints = false
        keyBindingKeyActionRow.addArrangedSubview(keyBindingKeyAssignButton)
        keyBindingKeyActionRow.addArrangedSubview(keyBindingKeyRemoveButton)
        keyBindingButtonRow.translatesAutoresizingMaskIntoConstraints = false
        keyBindingButtonRow.addSubview(recordKeyBindingButton)
        keyBindingButtonRow.addSubview(keyBindingMoreButton)
        pathEditorStack.addArrangedSubview(keyBindingStatusField)
        pathEditorStack.addArrangedSubview(keyBindingButtonRow)
        pathEditorStack.addArrangedSubview(keyBindingKeyActionRow)

        themePopupButton.translatesAutoresizingMaskIntoConstraints = false
        addThemeButton.translatesAutoresizingMaskIntoConstraints = false
        deleteThemeButton.translatesAutoresizingMaskIntoConstraints = false
        usesBackgroundColorButton.translatesAutoresizingMaskIntoConstraints = false
        backgroundColorWell.translatesAutoresizingMaskIntoConstraints = false
        backgroundAlphaLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundAlphaSlider.translatesAutoresizingMaskIntoConstraints = false
        usesForegroundColorButton.translatesAutoresizingMaskIntoConstraints = false
        foregroundColorWell.translatesAutoresizingMaskIntoConstraints = false

        let themeRow = NSStackView(views: [
            themePopupButton,
            addThemeButton,
            deleteThemeButton
        ])
        themeRow.orientation = .horizontal
        themeRow.spacing = 8
        themeRow.translatesAutoresizingMaskIntoConstraints = false

        let backgroundRow = NSStackView(views: [usesBackgroundColorButton, backgroundColorWell])
        backgroundRow.orientation = .horizontal
        backgroundRow.spacing = 8
        backgroundRow.translatesAutoresizingMaskIntoConstraints = false

        backgroundAlphaRow.orientation = .horizontal
        backgroundAlphaRow.spacing = 8
        backgroundAlphaRow.translatesAutoresizingMaskIntoConstraints = false
        backgroundAlphaRow.addArrangedSubview(backgroundAlphaLabel)
        backgroundAlphaRow.addArrangedSubview(backgroundAlphaSlider)

        let foregroundRow = NSStackView(views: [usesForegroundColorButton, foregroundColorWell])
        foregroundRow.orientation = .horizontal
        foregroundRow.spacing = 8
        foregroundRow.translatesAutoresizingMaskIntoConstraints = false

        appearanceEditorStack.orientation = .vertical
        appearanceEditorStack.spacing = 8
        appearanceEditorStack.translatesAutoresizingMaskIntoConstraints = false
        appearanceEditorStack.addArrangedSubview(themeRow)
        appearanceEditorStack.addArrangedSubview(backgroundRow)
        appearanceEditorStack.addArrangedSubview(backgroundAlphaRow)
        appearanceEditorStack.addArrangedSubview(foregroundRow)
        pathEditorStack.addArrangedSubview(appearanceEditorStack)

        let fileTypeMatchRow = NSStackView(views: [fileTypeExtensionsField, fileTypeOtherExtensionsButton])
        fileTypeMatchRow.orientation = .horizontal
        fileTypeMatchRow.distribution = .fill
        fileTypeMatchRow.spacing = 8
        fileTypeOtherExtensionsButton.setContentHuggingPriority(.required, for: .horizontal)

        let fileTypeApplicationRow = NSStackView(views: [fileTypeApplicationField, chooseFileTypeApplicationButton])
        fileTypeApplicationRow.orientation = .horizontal
        fileTypeApplicationRow.spacing = 8
        let fileTypeColorRow = NSStackView(views: [fileTypeUsesColorButton, fileTypeColorWell])
        fileTypeColorRow.orientation = .horizontal
        fileTypeColorRow.spacing = 8
        let fileTypeColorScopeRow = NSStackView(views: [fileTypeColorScopeLabel, fileTypeColorScopePopup])
        fileTypeColorScopeRow.orientation = .horizontal
        fileTypeColorScopeRow.spacing = 8
        let fileTypeEditorStack = NSStackView(views: [
            fileTypeMatchRow,
            fileTypeApplicationRow,
            fileTypeColorRow,
            fileTypeColorScopeRow
        ])
        fileTypeEditorStack.identifier = NSUserInterfaceItemIdentifier("fileTypeEditorStack")
        fileTypeEditorStack.orientation = .vertical
        fileTypeEditorStack.spacing = 8
        pathEditorStack.addArrangedSubview(fileTypeEditorStack)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.nextKeyView = tableView

        okButton.target = self
        okButton.action = #selector(okButtonClicked(_:))
        okButton.keyEquivalent = "\r"
        okButton.translatesAutoresizingMaskIntoConstraints = false

        cancelButton.target = self
        cancelButton.action = #selector(cancelButtonClicked(_:))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        importSettingsButton.target = self
        importSettingsButton.action = #selector(importSettingsButtonClicked(_:))
        importSettingsButton.translatesAutoresizingMaskIntoConstraints = false

        importSelectedSettingsButton.target = self
        importSelectedSettingsButton.action = #selector(importSelectedSettingsButtonClicked(_:))
        importSelectedSettingsButton.translatesAutoresizingMaskIntoConstraints = false

        exportSettingsButton.target = self
        exportSettingsButton.action = #selector(exportSettingsButtonClicked(_:))
        exportSettingsButton.translatesAutoresizingMaskIntoConstraints = false

        tableView.nextKeyView = okButton
        okButton.nextKeyView = cancelButton
        cancelButton.nextKeyView = importSettingsButton
        importSettingsButton.nextKeyView = importSelectedSettingsButton
        importSelectedSettingsButton.nextKeyView = exportSettingsButton
        exportSettingsButton.nextKeyView = segmentedControl

        container.addSubview(segmentedControl)
        container.addSubview(keyBindingSearchRow)
        container.addSubview(scrollView)
        container.addSubview(themePreviewView)
        container.addSubview(pathEditorStack)
        container.addSubview(okButton)
        container.addSubview(cancelButton)
        container.addSubview(importSettingsButton)
        container.addSubview(importSelectedSettingsButton)
        container.addSubview(exportSettingsButton)
        container.addSubview(keyBindingCaptureView)

        let pathEditorHeightConstraint = pathEditorStack.heightAnchor.constraint(equalToConstant: 0)
        self.pathEditorHeightConstraint = pathEditorHeightConstraint
        themePreviewView.translatesAutoresizingMaskIntoConstraints = false
        let scrollViewNormalTrailingConstraint = scrollView.trailingAnchor.constraint(
            equalTo: container.trailingAnchor,
            constant: -20
        )
        let scrollViewThemeTrailingConstraint = scrollView.trailingAnchor.constraint(
            equalTo: themePreviewView.leadingAnchor,
            constant: -12
        )
        self.scrollViewNormalTrailingConstraint = scrollViewNormalTrailingConstraint
        self.scrollViewThemeTrailingConstraint = scrollViewThemeTrailingConstraint
        let exportSettingsNormalLeadingConstraint = exportSettingsButton.leadingAnchor.constraint(
            equalTo: importSettingsButton.trailingAnchor,
            constant: 20
        )
        let exportSettingsPartialLeadingConstraint = exportSettingsButton.leadingAnchor.constraint(
            equalTo: importSelectedSettingsButton.trailingAnchor,
            constant: 20
        )
        self.exportSettingsNormalLeadingConstraint = exportSettingsNormalLeadingConstraint
        self.exportSettingsPartialLeadingConstraint = exportSettingsPartialLeadingConstraint

        let keyBindingSearchHeightConstraint = keyBindingSearchRow.heightAnchor.constraint(equalToConstant: 0)
        self.keyBindingSearchHeightConstraint = keyBindingSearchHeightConstraint
        let keyBindingCaptureHeightConstraint = keyBindingCaptureView.heightAnchor.constraint(equalToConstant: 0)
        self.keyBindingCaptureHeightConstraint = keyBindingCaptureHeightConstraint
        let keyBindingDetailHeightConstraint = keyBindingDetailScrollView.heightAnchor.constraint(equalToConstant: 28)
        self.keyBindingDetailHeightConstraint = keyBindingDetailHeightConstraint
        NSLayoutConstraint.activate([
            segmentedControl.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            segmentedControl.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            segmentedControl.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            keyBindingSearchRow.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            keyBindingSearchRow.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            keyBindingSearchRow.topAnchor.constraint(equalTo: keyBindingCaptureView.bottomAnchor),
            keyBindingSearchHeightConstraint,
            keyBindingCaptureView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            keyBindingCaptureView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            keyBindingCaptureView.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 8),
            keyBindingCaptureHeightConstraint,
            keyBindingSearchButton.widthAnchor.constraint(equalToConstant: 130),
            keyBindingClearSearchButton.widthAnchor.constraint(equalToConstant: 64),
            scrollView.topAnchor.constraint(equalTo: keyBindingSearchRow.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: pathEditorStack.topAnchor, constant: -10),
            scrollViewNormalTrailingConstraint,

            themePreviewView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            themePreviewView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            themePreviewView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            themePreviewView.widthAnchor.constraint(greaterThanOrEqualToConstant: 280),
            themePreviewView.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            themePreviewView.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.44),

            pathEditorStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            pathEditorStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            pathEditorStack.bottomAnchor.constraint(equalTo: okButton.topAnchor, constant: -16),
            pathEditorHeightConstraint,

            pathButtonRow.heightAnchor.constraint(equalToConstant: 30),
            deletePathButton.trailingAnchor.constraint(equalTo: pathButtonRow.trailingAnchor),
            deletePathButton.centerYAnchor.constraint(equalTo: pathButtonRow.centerYAnchor),
            updatePathButton.trailingAnchor.constraint(equalTo: deletePathButton.leadingAnchor, constant: -8),
            updatePathButton.centerYAnchor.constraint(equalTo: deletePathButton.centerYAnchor),
            addPathButton.trailingAnchor.constraint(equalTo: updatePathButton.leadingAnchor, constant: -8),
            addPathButton.centerYAnchor.constraint(equalTo: deletePathButton.centerYAnchor),
            movePathDownButton.trailingAnchor.constraint(equalTo: addPathButton.leadingAnchor, constant: -8),
            movePathDownButton.centerYAnchor.constraint(equalTo: deletePathButton.centerYAnchor),
            movePathUpButton.trailingAnchor.constraint(equalTo: movePathDownButton.leadingAnchor, constant: -8),
            movePathUpButton.centerYAnchor.constraint(equalTo: deletePathButton.centerYAnchor),

            keyBindingButtonRow.heightAnchor.constraint(equalToConstant: 30),
            keyBindingDetailHeightConstraint,
            keyBindingMoreButton.trailingAnchor.constraint(equalTo: keyBindingButtonRow.trailingAnchor),
            keyBindingMoreButton.centerYAnchor.constraint(equalTo: keyBindingButtonRow.centerYAnchor),
            keyBindingMoreButton.widthAnchor.constraint(equalToConstant: 40),
            recordKeyBindingButton.leadingAnchor.constraint(equalTo: keyBindingButtonRow.leadingAnchor),
            recordKeyBindingButton.centerYAnchor.constraint(equalTo: keyBindingButtonRow.centerYAnchor),
            keyBindingKeyActionRow.heightAnchor.constraint(equalToConstant: 30),

            themePopupButton.widthAnchor.constraint(equalToConstant: 160),
            addThemeButton.widthAnchor.constraint(equalToConstant: 180),
            deleteThemeButton.widthAnchor.constraint(equalToConstant: 180),
            backgroundColorWell.widthAnchor.constraint(equalToConstant: 80),
            backgroundAlphaLabel.widthAnchor.constraint(equalToConstant: 120),
            backgroundAlphaSlider.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
        foregroundColorWell.widthAnchor.constraint(equalToConstant: 80),
            chooseFileTypeApplicationButton.widthAnchor.constraint(equalToConstant: 90),
            fileTypeColorWell.widthAnchor.constraint(equalToConstant: 80),
            fileTypeColorScopePopup.widthAnchor.constraint(equalToConstant: 160),

            importSettingsButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            importSettingsButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            importSelectedSettingsButton.leadingAnchor.constraint(equalTo: importSettingsButton.trailingAnchor, constant: 8),
            importSelectedSettingsButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            exportSettingsNormalLeadingConstraint,
            exportSettingsButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor),
            exportSettingsButton.trailingAnchor.constraint(lessThanOrEqualTo: cancelButton.leadingAnchor, constant: -16),

            okButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            okButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -20),
            cancelButton.trailingAnchor.constraint(equalTo: okButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: okButton.centerYAnchor)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.defaultButtonCell = okButton.cell as? NSButtonCell
        view.window?.makeFirstResponder(isKeyBindingTabSelected ? keyBindingSearchField : tableView)
    }

    func prepareForPresentation(focusedCommandID: CommandID? = nil) {
        state = committedState
        keyBindingSearchField.stringValue = ""
        searchedKeyStrokes = []
        setKeyBindingCaptureActive(false)
        if let focusedCommandID,
           let tabIndex = state.tabs.firstIndex(where: { $0.title == "Keybindings" }),
           let commandIndex = CommandID.allCases.firstIndex(of: focusedCommandID) {
            state.selectTab(at: tabIndex)
            state.focusItem(at: commandIndex)
        }
        if isViewLoaded {
            render()
        }
    }

    @objc private func tabSelectionChanged(_ sender: NSSegmentedControl) {
        guard !isRendering else {
            return
        }

        state.selectTab(at: sender.selectedSegment)
        if !isKeyBindingTabSelected { clearKeyBindingSearch(shouldRefresh: false) }
        cancelRecordedKeyBinding()
        populatePathEditorFromFocusedRow()
        render()
        view.window?.makeFirstResponder(isKeyBindingTabSelected ? keyBindingSearchField : tableView)
    }

    private func moveTabSelection(by delta: Int) {
        state.moveTabSelection(by: delta)
        if !isKeyBindingTabSelected { clearKeyBindingSearch(shouldRefresh: false) }
        render()
        view.window?.makeFirstResponder(segmentedControl)
    }

    private func moveItemFocus(by delta: Int) {
        if isKeyBindingTabSelected {
            let commands = dataSource.keyBindingCommandIDs
            guard !commands.isEmpty else { return }
            let next = max(0, min(commands.count - 1, tableView.selectedRow + delta))
            if let index = CommandID.allCases.firstIndex(of: commands[next]) { state.focusItem(at: index) }
        } else if isPathTabSelected {
            state.moveJumpPathFocus(by: delta)
        } else if isFileTypesTabSelected {
            state.moveFileTypeAssociationFocus(by: delta)
        } else {
            state.moveItemFocus(by: delta)
        }
        if isKeyBindingTabSelected {
            cancelRecordedKeyBinding()
        }
        populatePathEditorFromFocusedRow()
        render()
    }

    private func focusItems() {
        state.focusItems()
        render()
    }

    private func focusItem(at index: Int) {
        guard !isRendering else {
            return
        }

        if isKeyBindingTabSelected {
            guard dataSource.keyBindingCommandIDs.indices.contains(index),
                  let commandIndex = CommandID.allCases.firstIndex(of: dataSource.keyBindingCommandIDs[index]) else {
                return
            }
            state.focusItem(at: commandIndex)
        } else if isPathTabSelected {
            state.focusJumpPath(at: index)
        } else if isFileTypesTabSelected {
            state.focusFileTypeAssociation(at: index)
        } else {
            state.focusItem(at: index)
        }
        if isKeyBindingTabSelected {
            cancelRecordedKeyBinding()
        }
        populatePathEditorFromFocusedRow()
        render()
    }

    private func toggleFocusedItem() {
        if state.toggleFocusedItem() != nil {
            render()
            return
        }

        guard state.cycleFocusedChoice() != nil else {
            return
        }

        render()
    }

    private func setChoiceForFocusedItem(_ value: SettingsChoiceValue) {
        guard let items = state.selectedTab?.items,
              items.indices.contains(state.focusedItemIndex),
              let choiceID = items[state.focusedItemIndex].choiceID else {
            return
        }

        state.setChoice(choiceID, to: value)
        render()
    }

    @objc private func addPathButtonClicked(_ sender: NSButton) {
        isFileTypesTabSelected ? addFileTypeAssociation() : addPathFromEditor()
    }

    @objc private func updatePathButtonClicked(_ sender: NSButton) {
        isFileTypesTabSelected ? updateFileTypeAssociation() : updateSelectedPathFromEditor()
    }

    @objc private func deletePathButtonClicked(_ sender: NSButton) {
        isFileTypesTabSelected ? deleteSelectedFileTypeAssociation() : deleteSelectedPath()
    }

    @objc private func movePathUpButtonClicked(_ sender: NSButton) {
        moveSelectedPath(by: -1)
    }

    @objc private func movePathDownButtonClicked(_ sender: NSButton) {
        moveSelectedPath(by: 1)
    }

    @objc private func recordKeyBindingButtonClicked(_ sender: NSButton) {
        beginRecordingKeyBinding()
    }

    @objc private func assignSearchedKeyButtonClicked(_ sender: NSButton) {
        assignSearchedKey()
    }

    private func assignSearchedKey() {
        guard !searchedKeyStrokes.isEmpty else { return }
        let sequence = KeyBindingSequence(searchedKeyStrokes)
        let exact = state.keyBindingSet.bindings(startingWith: searchedKeyStrokes)
            .filter { $0.sequence.strokes == searchedKeyStrokes }
        if exact.count == 1 {
            presentKeyBindingAssignment(for: sequence, replacing: exact[0].commandID)
        } else if exact.isEmpty && state.keyBindingSet.canAssign(sequence) {
            presentKeyBindingAssignment(for: sequence, replacing: nil)
        }
    }

    @objc private func removeSearchedKeyButtonClicked(_ sender: NSButton) {
        let exact = state.keyBindingSet.bindings(startingWith: searchedKeyStrokes)
            .filter { $0.sequence.strokes == searchedKeyStrokes }
        guard exact.count == 1,
              let index = state.keyBindingSet.sequences(for: exact[0].commandID)
                .firstIndex(where: { $0.strokes == searchedKeyStrokes }) else { return }
        state.removeKeyBindingSequence(at: index, from: exact[0].commandID)
        refreshKeyBindingResults()
        view.window?.makeFirstResponder(keyBindingCaptureView)
    }

    @objc private func resetCommandMenuItemSelected(_ sender: NSMenuItem) {
        resetFocusedKeyBindingToDefault()
    }

    @objc private func resetAllMenuItemSelected(_ sender: NSMenuItem) {
        state.resetAllKeyBindingsToDefault()
        cancelRecordedKeyBinding()
        render()
    }

    @objc private func searchKeyBindingButtonClicked(_ sender: NSButton) {
        searchedKeyStrokes = []
        keyBindingSearchField.stringValue = ""
        setKeyBindingCaptureActive(true)
        refreshKeyBindingResults()
        view.window?.makeFirstResponder(keyBindingCaptureView)
    }

    @objc private func clearKeyBindingSearchButtonClicked(_ sender: NSButton) {
        clearKeyBindingSearch()
    }

    private func clearKeyBindingSearch(shouldRefresh: Bool = true) {
        setKeyBindingCaptureActive(false)
        searchedKeyStrokes = []
        keyBindingSearchField.stringValue = ""
        if shouldRefresh {
            refreshKeyBindingResults()
            view.window?.makeFirstResponder(keyBindingSearchField)
        }
    }

    private func setKeyBindingCaptureActive(_ active: Bool) {
        guard isCapturingKeySearch != active else { return }
        isCapturingKeySearch = active
        keyBindingCaptureView.isHidden = !active
        keyBindingCaptureHeightConstraint?.constant = active ? 112 : 0
        setCaptureInteractionActive(active)
        updateKeySearchCaptureDisplay()
    }

    private func setCaptureInteractionActive(_ active: Bool) {
        if active {
            captureDisabledControlStates = captureDisabledControls.map { ($0, $0.isEnabled) }
        } else {
            for (control, wasEnabled) in captureDisabledControlStates { control.isEnabled = wasEnabled }
            captureDisabledControlStates = []
        }
        enforceCaptureDisabledControls()
        let closeButton = view.window?.standardWindowButton(.closeButton)
        let miniaturizeButton = view.window?.standardWindowButton(.miniaturizeButton)
        if active {
            closeButtonWasEnabled = closeButton?.isEnabled
            miniaturizeButtonWasEnabled = miniaturizeButton?.isEnabled
            closeButton?.isEnabled = false
            miniaturizeButton?.isEnabled = false
        } else {
            if let closeButtonWasEnabled { closeButton?.isEnabled = closeButtonWasEnabled }
            if let miniaturizeButtonWasEnabled { miniaturizeButton?.isEnabled = miniaturizeButtonWasEnabled }
            closeButtonWasEnabled = nil
            miniaturizeButtonWasEnabled = nil
        }
    }

    private var captureDisabledControls: [NSControl] {
        [segmentedControl, keyBindingSearchField, keyBindingSearchButton,
         keyBindingClearSearchButton, keyBindingDetailTable,
         recordKeyBindingButton, keyBindingMoreButton, okButton, cancelButton,
         importSettingsButton, importSelectedSettingsButton, exportSettingsButton]
    }

    private func enforceCaptureDisabledControls() {
        guard isCapturingKeySearch || recordingCommandID != nil else { return }
        for control in captureDisabledControls { control.isEnabled = false }
    }

    private func updateKeySearchCaptureDisplay() {
        let status: String
        if searchedKeyStrokes.isEmpty {
            status = L10n.string("settings.keybinding.captureHelp")
        } else if !dataSource.keyBindingCommandIDs.isEmpty {
            status = L10n.format("settings.keybinding.captureMatches", dataSource.keyBindingCommandIDs.count)
        } else if state.keyBindingSet.canAssign(KeyBindingSequence(searchedKeyStrokes)) {
            status = L10n.string("settings.keybinding.captureUnassigned")
        } else {
            status = L10n.string("settings.keybinding.captureUnavailable")
        }
        keyBindingCaptureView.update(
            strokes: searchedKeyStrokes,
            title: L10n.string("settings.keybinding.captureTitle"),
            status: status
        )
    }

    @objc private func commandTableClicked(_ sender: NSTableView) {
        if isKeyBindingTabSelected && isCapturingKeySearch { leaveKeySearchForSelectedCommand() }
    }

    @objc private func okButtonClicked(_ sender: NSButton) {
        saveAndClose()
    }

    @objc private func cancelButtonClicked(_ sender: NSButton) {
        discardAndClose()
    }

    @objc private func tableViewDoubleClicked(_ sender: NSTableView) {
        focusItem(at: sender.clickedRow)
        toggleFocusedItem()
    }

    private func saveAndClose() {
        guard !hasUnappliedListEditorChanges else {
            showUnappliedListEditorAlert()
            return
        }
        guard canApplyKeyBindingSet(state.keyBindingSet) else {
            showErrorAlert(
                title: L10n.string("settings.alert.keyBindingConflicts.title"),
                message: L10n.string("settings.alert.keyBindingConflicts.message")
            )
            return
        }
        postChangesIfNeeded(from: committedState, to: state)
        committedState = state
        isClosingAfterCommit = true
        closeSettingsWindow()
    }

    private func discardAndClose() {
        state = committedState
        render()
        closeSettingsWindow()
    }

    private func closeSettingsWindow() {
        closeColorPanel()
        onDismiss?()
    }

    private func render() {
        isRendering = true
        defer { isRendering = false }

        applyLocalizedStrings()
        segmentedControl.selectedSegment = state.selectedTabIndex
        if isPathTabSelected {
            dataSource.mode = .jumpPaths
        } else if isFileTypesTabSelected {
            dataSource.mode = .fileTypes
        } else if isKeyBindingTabSelected {
            dataSource.mode = .keyBindings
        } else if isThemeTabSelected {
            dataSource.mode = .appearance
        } else {
            dataSource.mode = .settings
        }
        dataSource.items = state.selectedTab?.items ?? []
        dataSource.jumpPathEntries = state.jumpPathEntries
        dataSource.keyBindingSet = state.keyBindingSet
        dataSource.keyBindingCommandIDs = matchingKeyBindingCommands()
        updateKeyBindingEmptyResult()
        dataSource.displayTheme = state.displayThemeSet.selectedTheme
        dataSource.fileTypeAssociations = state.fileTypeAssociations
        dataSource.incrementalSearchPriority = state.incrementalSearchPriority
        dataSource.showsCommandPaletteButton = state.showsCommandPaletteButton
        dataSource.showsPreviewPane = state.showsPreviewPane
        dataSource.showsHiddenFiles = state.showsHiddenFiles
        dataSource.usesAlternatingRowBackgrounds = state.usesAlternatingRowBackgrounds
        dataSource.showsFileIcons = state.showsFileIcons
        dataSource.showsFileTagColors = state.showsFileTagColors
        dataSource.showsFileExtensionsSeparately = state.showsFileExtensionsSeparately
        dataSource.showsMultiStrokeKeyCandidates = state.showsMultiStrokeKeyCandidates
        dataSource.movesCursorAfterMarking = state.movesCursorAfterMarking
        dataSource.movesToCreatedFolder = state.movesToCreatedFolder
        dataSource.selectsPreviousDirectoryAfterMovingToParent = state.selectsPreviousDirectoryAfterMovingToParent
        dataSource.confirmsBeforeCopy = state.confirmsBeforeCopy
        dataSource.confirmsBeforeMove = state.confirmsBeforeMove
        dataSource.confirmsBeforeTrash = state.confirmsBeforeTrash
        dataSource.confirmsBeforeQuit = state.confirmsBeforeQuit
        dataSource.allowsExternalFileDrag = state.allowsExternalFileDrag
        dataSource.treatZipAsDirectory = state.treatZipAsDirectory
        dataSource.fileOperationDetailLogLimit = state.fileOperationDetailLogLimit
        dataSource.fileListFontSize = state.fileListFontSize
        dataSource.appLanguage = state.appLanguage
        dataSource.returnKeyBehavior = state.returnKeyBehavior
        dataSource.incrementalSearchMatchMode = state.incrementalSearchMatchMode
        dataSource.previewPanePosition = state.previewPanePosition
        dataSource.leftStartupPathMode = state.leftStartupPathMode
        dataSource.rightStartupPathMode = state.rightStartupPathMode
        dataSource.leftStartupPath = state.leftStartupPath
        dataSource.rightStartupPath = state.rightStartupPath
        configureTableColumns()
        configureThemePreview()
        tableView.reloadData()

        pathEditorStack.isHidden = !isPathTabSelected
            && !isFileTypesTabSelected
            && !isKeyBindingTabSelected
            && !isThemeTabSelected
        addPathButton.isHidden = !isPathTabSelected && !isFileTypesTabSelected
        updatePathButton.isHidden = !isPathTabSelected && !isFileTypesTabSelected
        deletePathButton.isHidden = !isPathTabSelected && !isFileTypesTabSelected
        movePathUpButton.isHidden = !isPathTabSelected
        movePathDownButton.isHidden = !isPathTabSelected
        pathNameField.isHidden = !isPathTabSelected
        pathField.isHidden = !isPathTabSelected
        pathButtonRow.isHidden = !isPathTabSelected && !isFileTypesTabSelected
        let fileTypeEditorStack = pathEditorStack.arrangedSubviews.first {
            $0.identifier == NSUserInterfaceItemIdentifier("fileTypeEditorStack")
        }
        fileTypeEditorStack?.isHidden = !isFileTypesTabSelected
        fileTypeExtensionsField.isHidden = !isFileTypesTabSelected
        fileTypeOtherExtensionsButton.isHidden = !isFileTypesTabSelected
        fileTypeApplicationField.isHidden = !isFileTypesTabSelected
        chooseFileTypeApplicationButton.isHidden = !isFileTypesTabSelected
        fileTypeUsesColorButton.isHidden = !isFileTypesTabSelected
        fileTypeColorWell.isHidden = !isFileTypesTabSelected
        fileTypeColorScopeLabel.isHidden = !isFileTypesTabSelected
        fileTypeColorScopePopup.isHidden = !isFileTypesTabSelected
        let canImportSelectedSettings = isKeyBindingTabSelected || isThemeTabSelected
        importSelectedSettingsButton.isHidden = !canImportSelectedSettings
        exportSettingsNormalLeadingConstraint?.isActive = !canImportSelectedSettings
        exportSettingsPartialLeadingConstraint?.isActive = canImportSelectedSettings
        if isKeyBindingTabSelected {
            importSelectedSettingsButton.title = L10n.string("settings.button.importKeyBindingsOnly")
            importSettingsButton.nextKeyView = importSelectedSettingsButton
        } else if isThemeTabSelected {
            importSelectedSettingsButton.title = L10n.string("settings.button.importThemesOnly")
            importSettingsButton.nextKeyView = importSelectedSettingsButton
        } else {
            importSettingsButton.nextKeyView = exportSettingsButton
        }
        keyBindingSearchRow.isHidden = !isKeyBindingTabSelected || isCapturingKeySearch
        keyBindingSearchHeightConstraint?.constant = isKeyBindingTabSelected && !isCapturingKeySearch ? 30 : 0
        tableView.allowsEmptySelection = isKeyBindingTabSelected
        segmentedControl.nextKeyView = isKeyBindingTabSelected ? keyBindingSearchField : tableView
        if isKeyBindingTabSelected {
            keyBindingSearchField.nextKeyView = keyBindingSearchButton
            keyBindingSearchButton.nextKeyView = keyBindingClearSearchButton
            keyBindingClearSearchButton.nextKeyView = tableView
            tableView.nextKeyView = keyBindingDetailTable
            keyBindingDetailTable.nextKeyView = recordKeyBindingButton
            recordKeyBindingButton.nextKeyView = keyBindingMoreButton
            keyBindingMoreButton.nextKeyView = okButton
        } else {
            tableView.nextKeyView = okButton
        }
        appearanceEditorStack.isHidden = !isThemeTabSelected
        addPathButton.isEnabled = true
        updatePathButton.isEnabled = isFileTypesTabSelected
            ? state.fileTypeAssociations.indices.contains(state.focusedItemIndex)
            : state.jumpPathEntries.indices.contains(state.focusedItemIndex)
        deletePathButton.isEnabled = updatePathButton.isEnabled
        movePathUpButton.isEnabled = state.focusedItemIndex > 0
        movePathDownButton.isEnabled = state.focusedItemIndex < state.jumpPathEntries.count - 1
        recordKeyBindingButton.isEnabled = focusedCommandID != nil
        updateKeyBindingDetails()
        keyBindingStatusField.stringValue = keyBindingStatusText()
        updateKeyBindingModeUI()
        if recordingCommandID != nil { updateRecordingCaptureDisplay() }
        enforceCaptureDisabledControls()
        renderAppearanceEditor()
        renderFileTypeEditor()

        let rowCount = dataSource.numberOfRows(in: tableView)
        let selectedRow = isKeyBindingTabSelected
            ? dataSource.keyBindingCommandIDs.firstIndex(of: focusedCommandID ?? .moveSelectionUp)
            : (0..<rowCount).contains(state.focusedItemIndex) ? state.focusedItemIndex : nil
        if let selectedRow {
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            tableView.scrollRowToVisible(selectedRow)
        } else {
            tableView.deselectAll(nil)
        }

        if view.window?.firstResponder == keyBindingSearchField
            || view.window?.firstResponder == keyBindingSearchField.currentEditor()
            || isCapturingKeySearch || recordingCommandID != nil {
            return
        }
        switch state.focusArea {
        case .tabs:
            view.window?.makeFirstResponder(segmentedControl)
        case .items:
            view.window?.makeFirstResponder(tableView)
        }
    }

    private func applyLocalizedStrings() {
        view.window?.title = L10n.string("settings.window.title")
        segmentedControl.setLabels(state.tabs.map(\.localizedTitle))
        okButton.title = L10n.string("settings.button.ok")
        cancelButton.title = L10n.string("settings.button.cancel")
        importSettingsButton.title = L10n.string("settings.button.importSettings")
        exportSettingsButton.title = L10n.string("settings.button.exportSettings")
        addPathButton.title = L10n.string("settings.button.add")
        updatePathButton.title = L10n.string("settings.button.update")
        deletePathButton.title = L10n.string("settings.button.delete")
        movePathUpButton.title = L10n.string("settings.button.moveUp")
        movePathDownButton.title = L10n.string("settings.button.moveDown")
        recordKeyBindingButton.title = L10n.string("settings.button.addBinding")
        keyBindingSearchField.placeholderString = L10n.string("settings.keybinding.searchPlaceholder")
        keyBindingSearchButton.title = isCapturingKeySearch
            ? L10n.string("settings.keybinding.keySearchRecording") : L10n.string("settings.button.searchByKey")
        keyBindingClearSearchButton.title = L10n.string("settings.button.clearSearch")
        keyBindingKeyRemoveButton.title = L10n.string("settings.button.removeSearchedKey")
        keyBindingMoreButton.item(at: 1)?.title = L10n.string("settings.button.resetCommand")
        keyBindingMoreButton.item(at: 2)?.title = L10n.string("settings.button.resetAll")
        keyBindingDetailLabel.stringValue = L10n.string("settings.keybinding.details")
        addThemeButton.title = L10n.string("settings.button.duplicateCurrentTheme")
        deleteThemeButton.title = L10n.string("settings.button.deleteCurrentTheme")
        usesBackgroundColorButton.title = L10n.string("settings.checkbox.useBackgroundColor")
        usesForegroundColorButton.title = L10n.string("settings.checkbox.useForegroundColor")
        pathNameField.placeholderString = L10n.string("settings.placeholder.displayName")
        pathField.placeholderString = L10n.string("settings.placeholder.path")
        fileTypeExtensionsField.placeholderString = L10n.string("settings.placeholder.extensions")
        fileTypeOtherExtensionsButton.title = L10n.string("settings.checkbox.fileTypeOtherExtensions")
        fileTypeApplicationField.placeholderString = L10n.string("settings.placeholder.application")
        chooseFileTypeApplicationButton.title = L10n.string("settings.button.chooseApplication")
        fileTypeUsesColorButton.title = L10n.string("settings.checkbox.useFileTypeColor")
        fileTypeColorScopeLabel.stringValue = L10n.string("settings.label.fileTypeColorScope")
    }

    private func postChangesIfNeeded(from oldState: SettingsState, to newState: SettingsState) {
        var userInfo: [String: Any] = [:]

        if oldState.showsPreviewPane != newState.showsPreviewPane {
            userInfo[SettingsNotificationKey.showsPreviewPane] = newState.showsPreviewPane
        }

        if oldState.previewPanePosition != newState.previewPanePosition {
            userInfo[SettingsNotificationKey.previewPanePosition] = newState.previewPanePosition
        }

        if oldState.showsHiddenFiles != newState.showsHiddenFiles {
            userInfo[SettingsNotificationKey.showsHiddenFiles] = newState.showsHiddenFiles
        }

        if oldState.incrementalSearchPriority != newState.incrementalSearchPriority {
            userInfo[SettingsNotificationKey.incrementalSearchPriority] = newState.incrementalSearchPriority
        }

        if oldState.showsCommandPaletteButton != newState.showsCommandPaletteButton {
            userInfo[SettingsNotificationKey.showsCommandPaletteButton] = newState.showsCommandPaletteButton
        }

        if oldState.usesAlternatingRowBackgrounds != newState.usesAlternatingRowBackgrounds {
            userInfo[SettingsNotificationKey.usesAlternatingRowBackgrounds] = newState.usesAlternatingRowBackgrounds
        }

        if oldState.showsFileIcons != newState.showsFileIcons {
            userInfo[SettingsNotificationKey.showsFileIcons] = newState.showsFileIcons
        }

        if oldState.showsFileTagColors != newState.showsFileTagColors {
            userInfo[SettingsNotificationKey.showsFileTagColors] = newState.showsFileTagColors
        }

        if oldState.showsFileExtensionsSeparately != newState.showsFileExtensionsSeparately {
            userInfo[SettingsNotificationKey.showsFileExtensionsSeparately] = newState.showsFileExtensionsSeparately
        }

        if oldState.showsMultiStrokeKeyCandidates != newState.showsMultiStrokeKeyCandidates {
            userInfo[SettingsNotificationKey.showsMultiStrokeKeyCandidates] = newState.showsMultiStrokeKeyCandidates
        }

        if oldState.movesCursorAfterMarking != newState.movesCursorAfterMarking {
            userInfo[SettingsNotificationKey.movesCursorAfterMarking] = newState.movesCursorAfterMarking
        }

        if oldState.movesToCreatedFolder != newState.movesToCreatedFolder {
            userInfo[SettingsNotificationKey.movesToCreatedFolder] = newState.movesToCreatedFolder
        }

        if oldState.selectsPreviousDirectoryAfterMovingToParent != newState.selectsPreviousDirectoryAfterMovingToParent {
            userInfo[SettingsNotificationKey.selectsPreviousDirectoryAfterMovingToParent] = newState.selectsPreviousDirectoryAfterMovingToParent
        }

        if oldState.confirmsBeforeCopy != newState.confirmsBeforeCopy {
            userInfo[SettingsNotificationKey.confirmsBeforeCopy] = newState.confirmsBeforeCopy
        }

        if oldState.confirmsBeforeMove != newState.confirmsBeforeMove {
            userInfo[SettingsNotificationKey.confirmsBeforeMove] = newState.confirmsBeforeMove
        }

        if oldState.confirmsBeforeTrash != newState.confirmsBeforeTrash {
            userInfo[SettingsNotificationKey.confirmsBeforeTrash] = newState.confirmsBeforeTrash
        }

        if oldState.confirmsBeforeQuit != newState.confirmsBeforeQuit {
            userInfo[SettingsNotificationKey.confirmsBeforeQuit] = newState.confirmsBeforeQuit
        }

        if oldState.allowsExternalFileDrag != newState.allowsExternalFileDrag {
            userInfo[SettingsNotificationKey.allowsExternalFileDrag] = newState.allowsExternalFileDrag
        }

        if oldState.treatZipAsDirectory != newState.treatZipAsDirectory {
            userInfo[SettingsNotificationKey.treatZipAsDirectory] = newState.treatZipAsDirectory
        }

        if oldState.fileOperationDetailLogLimit != newState.fileOperationDetailLogLimit {
            userInfo[SettingsNotificationKey.fileOperationDetailLogLimit] = newState.fileOperationDetailLogLimit
        }

        if oldState.fileListFontSize != newState.fileListFontSize {
            userInfo[SettingsNotificationKey.fileListFontSize] = newState.fileListFontSize
        }

        if oldState.appLanguage != newState.appLanguage {
            userInfo[SettingsNotificationKey.appLanguage] = newState.appLanguage
        }

        if oldState.returnKeyBehavior != newState.returnKeyBehavior {
            userInfo[SettingsNotificationKey.returnKeyBehavior] = newState.returnKeyBehavior
        }

        if oldState.incrementalSearchMatchMode != newState.incrementalSearchMatchMode {
            userInfo[SettingsNotificationKey.incrementalSearchMatchMode] = newState.incrementalSearchMatchMode
        }

        if oldState.leftStartupPathMode != newState.leftStartupPathMode {
            userInfo[SettingsNotificationKey.leftStartupPathMode] = newState.leftStartupPathMode
        }

        if oldState.rightStartupPathMode != newState.rightStartupPathMode {
            userInfo[SettingsNotificationKey.rightStartupPathMode] = newState.rightStartupPathMode
        }

        if oldState.leftStartupPath != newState.leftStartupPath {
            userInfo[SettingsNotificationKey.leftStartupPath] = newState.leftStartupPath
        }

        if oldState.rightStartupPath != newState.rightStartupPath {
            userInfo[SettingsNotificationKey.rightStartupPath] = newState.rightStartupPath
        }

        if oldState.keyBindingSet != newState.keyBindingSet {
            userInfo[SettingsNotificationKey.keyBindingSet] = newState.keyBindingSet
        }

        if oldState.displayThemeSet != newState.displayThemeSet {
            userInfo[SettingsNotificationKey.displayThemeSet] = newState.displayThemeSet
        }

        if oldState.fileTypeAssociations != newState.fileTypeAssociations {
            userInfo[SettingsNotificationKey.fileTypeAssociations] = newState.fileTypeAssociations
        }

        if oldState.fileTypeColorScope != newState.fileTypeColorScope {
            userInfo[SettingsNotificationKey.fileTypeColorScope] = newState.fileTypeColorScope
        }

        if !userInfo.isEmpty {
            NotificationCenter.default.post(name: .settingsDidChange, object: self, userInfo: userInfo)
        }

        if oldState.jumpPathEntries != newState.jumpPathEntries {
            NotificationCenter.default.post(
                name: .jumpPathEntriesDidChange,
                object: self,
                userInfo: [SettingsNotificationKey.jumpPathEntries: newState.jumpPathEntries]
            )
        }
    }

    @objc private func importSettingsButtonClicked(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.title = L10n.string("settings.panel.import.title")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            state = try portableSettingsService.readSettingsState(from: url, defaultState: committedState)
            cancelRecordedKeyBinding()
            populatePathEditorFromFocusedRow()
            render()
            showInformationalAlert(
                title: L10n.string("settings.alert.importSucceeded.title"),
                message: L10n.string("settings.alert.importSucceeded.message")
            )
        } catch {
            showErrorAlert(
                title: L10n.string("settings.alert.importFailed.title"),
                message: L10n.format("settings.alert.importFailed.message", error.localizedDescription)
            )
        }
    }

    @objc private func importSelectedSettingsButtonClicked(_ sender: NSButton) {
        let isImportingKeyBindings = isKeyBindingTabSelected
        let isImportingThemes = isThemeTabSelected
        guard isImportingKeyBindings || isImportingThemes else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = L10n.string(
            isImportingKeyBindings
                ? "settings.panel.importKeyBindings.title"
                : "settings.panel.importThemes.title"
        )
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            let title: String
            let message: String
            if isImportingKeyBindings {
                state.setKeyBindingSet(try portableSettingsService.readKeyBindingSet(from: url))
                cancelRecordedKeyBinding()
                title = L10n.string("settings.alert.importKeyBindingsSucceeded.title")
                message = L10n.string("settings.alert.importKeyBindingsSucceeded.message")
            } else {
                state.setDisplayThemeSet(
                    try portableSettingsService.readDisplayThemeSet(
                        from: url,
                        fallbackThemeSet: state.displayThemeSet
                    )
                )
                title = L10n.string("settings.alert.importThemesSucceeded.title")
                message = L10n.string("settings.alert.importThemesSucceeded.message")
            }
            render()
            showInformationalAlert(title: title, message: message)
        } catch {
            showErrorAlert(
                title: L10n.string(
                    isImportingKeyBindings
                        ? "settings.alert.importKeyBindingsFailed.title"
                        : "settings.alert.importThemesFailed.title"
                ),
                message: L10n.format(
                    isImportingKeyBindings
                        ? "settings.alert.importKeyBindingsFailed.message"
                        : "settings.alert.importThemesFailed.message",
                    error.localizedDescription
                )
            )
        }
    }

    @objc private func exportSettingsButtonClicked(_ sender: NSButton) {
        let panel = NSSavePanel()
        panel.title = L10n.string("settings.panel.export.title")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "antlers-settings.json"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        do {
            try portableSettingsService.writeSettings(state, to: url)
            showInformationalAlert(
                title: L10n.string("settings.alert.exportSucceeded.title"),
                message: L10n.string("settings.alert.exportSucceeded.message")
            )
        } catch {
            showErrorAlert(
                title: L10n.string("settings.alert.exportFailed.title"),
                message: L10n.format("settings.alert.exportFailed.message", error.localizedDescription)
            )
        }
    }

    private func showInformationalAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("settings.button.ok"))
        presentAlert(alert)
    }

    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("settings.button.ok"))
        presentAlert(alert)
    }

    private func showUnappliedListEditorAlert() {
        let requiresUpdate = updatePathButton.isEnabled
        let alert = NSAlert()
        alert.messageText = L10n.string("settings.alert.unappliedListEditor.title")
        alert.informativeText = L10n.string(
            requiresUpdate
                ? "settings.alert.unappliedListEditor.updateMessage"
                : "settings.alert.unappliedListEditor.addMessage"
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("settings.button.ok"))

        let actionButton = requiresUpdate ? updatePathButton : addPathButton
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] _ in
                self?.view.window?.makeFirstResponder(actionButton)
            }
        } else {
            alert.runModal()
        }
    }

    private func presentAlert(_ alert: NSAlert) {
        if let window = view.window {
            alert.beginSheetModal(for: window) { _ in }
        } else {
            alert.runModal()
        }
    }

    private func configureTableColumns() {
        let targetIdentifiers: [NSUserInterfaceItemIdentifier]
        if isKeyBindingTabSelected {
            targetIdentifiers = [
                SettingsDataSource.Column.category,
                SettingsDataSource.Column.command,
                SettingsDataSource.Column.bindings,
                SettingsDataSource.Column.status
            ]
        } else if isPathTabSelected {
            targetIdentifiers = [
                SettingsDataSource.Column.bookmarkShortcut,
                SettingsDataSource.Column.bookmarkName,
                SettingsDataSource.Column.bookmarkPath
            ]
        } else if isFileTypesTabSelected {
            targetIdentifiers = [
                SettingsDataSource.Column.fileTypeExtensions,
                SettingsDataSource.Column.fileTypeApplication,
                SettingsDataSource.Column.fileTypeColor
            ]
        } else {
            targetIdentifiers = [SettingsDataSource.Column.setting]
        }
        let currentIdentifiers = tableView.tableColumns.map(\.identifier)
        guard currentIdentifiers != targetIdentifiers else {
            return
        }

        for column in tableView.tableColumns {
            tableView.removeTableColumn(column)
        }

        if isKeyBindingTabSelected {
            tableView.headerView = NSTableHeaderView()
            addTableColumn(identifier: SettingsDataSource.Column.category, title: L10n.string("settings.column.category"), width: 120)
            addTableColumn(identifier: SettingsDataSource.Column.command, title: L10n.string("settings.column.command"), width: 220)
            addTableColumn(identifier: SettingsDataSource.Column.bindings, title: L10n.string("settings.column.bindings"), width: 150)
            addTableColumn(identifier: SettingsDataSource.Column.status, title: L10n.string("settings.column.status"), width: 110)
        } else if isPathTabSelected {
            tableView.headerView = NSTableHeaderView()
            addTableColumn(
                identifier: SettingsDataSource.Column.bookmarkShortcut,
                title: L10n.string("settings.column.shortcut"),
                width: 44,
                minWidth: 44,
                resizingMask: []
            )
            addTableColumn(identifier: SettingsDataSource.Column.bookmarkName, title: L10n.string("settings.column.name"), width: 180)
            addTableColumn(identifier: SettingsDataSource.Column.bookmarkPath, title: L10n.string("settings.column.path"), width: 380)
        } else if isFileTypesTabSelected {
            tableView.headerView = NSTableHeaderView()
            addTableColumn(identifier: SettingsDataSource.Column.fileTypeExtensions, title: L10n.string("settings.column.extensions"), width: 180)
            addTableColumn(identifier: SettingsDataSource.Column.fileTypeApplication, title: L10n.string("settings.column.application"), width: 260)
            addTableColumn(identifier: SettingsDataSource.Column.fileTypeColor, title: L10n.string("settings.column.color"), width: 120)
        } else {
            tableView.headerView = nil
            addTableColumn(identifier: SettingsDataSource.Column.setting, title: L10n.string("settings.column.setting"), width: 560)
        }
    }

    private func configureThemePreview() {
        let showsPreview = isThemeTabSelected
        themePreviewView.isHidden = !showsPreview
        scrollViewNormalTrailingConstraint?.isActive = !showsPreview
        scrollViewThemeTrailingConstraint?.isActive = showsPreview
        guard showsPreview else {
            return
        }

        themePreviewView.render(theme: state.displayThemeSet.selectedTheme)
    }

    private func addTableColumn(
        identifier: NSUserInterfaceItemIdentifier,
        title: String,
        width: CGFloat,
        minWidth: CGFloat = 80,
        resizingMask: NSTableColumn.ResizingOptions = .autoresizingMask
    ) {
        let column = NSTableColumn(identifier: identifier)
        column.title = title
        column.width = width
        column.minWidth = minWidth
        column.resizingMask = resizingMask
        tableView.addTableColumn(column)
    }

    @objc private func jumpPathEntriesDidChange(_ notification: Notification) {
        if let sender = notification.object as AnyObject?, sender === self {
            return
        }

        guard let entries = notification.userInfo?[SettingsNotificationKey.jumpPathEntries] as? [JumpPathEntry] else {
            return
        }

        committedState.setJumpPathEntries(entries)
        state.setJumpPathEntries(entries)
        if isViewLoaded {
            render()
        }
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        if let sender = notification.object as AnyObject?, sender === self {
            return
        }

        if let showsHiddenFiles = notification.userInfo?[SettingsNotificationKey.showsHiddenFiles] as? Bool {
            committedState.setToggle(.showHiddenFiles, isOn: showsHiddenFiles)
            state.setToggle(.showHiddenFiles, isOn: showsHiddenFiles)
        }

        if let incrementalSearchPriority = notification.userInfo?[SettingsNotificationKey.incrementalSearchPriority] as? Bool {
            committedState.setToggle(.incrementalSearchPriority, isOn: incrementalSearchPriority)
            state.setToggle(.incrementalSearchPriority, isOn: incrementalSearchPriority)
        }

        if let showsButton = notification.userInfo?[SettingsNotificationKey.showsCommandPaletteButton] as? Bool {
            committedState.setToggle(.showCommandPaletteButton, isOn: showsButton)
            state.setToggle(.showCommandPaletteButton, isOn: showsButton)
        }

        if let showsPreviewPane = notification.userInfo?[SettingsNotificationKey.showsPreviewPane] as? Bool {
            committedState.setToggle(.showPreviewPane, isOn: showsPreviewPane)
            state.setToggle(.showPreviewPane, isOn: showsPreviewPane)
        }

        if let previewPanePosition = notification.userInfo?[SettingsNotificationKey.previewPanePosition] as? PreviewPanePosition {
            committedState.setChoice(.previewPanePosition, to: .previewPanePosition(previewPanePosition))
            state.setChoice(.previewPanePosition, to: .previewPanePosition(previewPanePosition))
        }

        if let usesAlternatingRowBackgrounds = notification.userInfo?[SettingsNotificationKey.usesAlternatingRowBackgrounds] as? Bool {
            committedState.setToggle(.useAlternatingRowBackgrounds, isOn: usesAlternatingRowBackgrounds)
            state.setToggle(.useAlternatingRowBackgrounds, isOn: usesAlternatingRowBackgrounds)
        }

        if let showsFileIcons = notification.userInfo?[SettingsNotificationKey.showsFileIcons] as? Bool {
            committedState.setToggle(.showFileIcons, isOn: showsFileIcons)
            state.setToggle(.showFileIcons, isOn: showsFileIcons)
        }

        if let showsFileTagColors = notification.userInfo?[SettingsNotificationKey.showsFileTagColors] as? Bool {
            committedState.setToggle(.showFileTagColors, isOn: showsFileTagColors)
            state.setToggle(.showFileTagColors, isOn: showsFileTagColors)
        }

        if let showsFileExtensionsSeparately = notification.userInfo?[SettingsNotificationKey.showsFileExtensionsSeparately] as? Bool {
            committedState.setToggle(.showFileExtensionsSeparately, isOn: showsFileExtensionsSeparately)
            state.setToggle(.showFileExtensionsSeparately, isOn: showsFileExtensionsSeparately)
        }
        if let showsMultiStrokeKeyCandidates = notification.userInfo?[SettingsNotificationKey.showsMultiStrokeKeyCandidates] as? Bool {
            committedState.setToggle(.showMultiStrokeKeyCandidates, isOn: showsMultiStrokeKeyCandidates)
            state.setToggle(.showMultiStrokeKeyCandidates, isOn: showsMultiStrokeKeyCandidates)
        }

        if let movesCursorAfterMarking = notification.userInfo?[SettingsNotificationKey.movesCursorAfterMarking] as? Bool {
            committedState.setToggle(.moveCursorAfterMarking, isOn: movesCursorAfterMarking)
            state.setToggle(.moveCursorAfterMarking, isOn: movesCursorAfterMarking)
        }

        if let movesToCreatedFolder = notification.userInfo?[SettingsNotificationKey.movesToCreatedFolder] as? Bool {
            committedState.setToggle(.moveToCreatedFolder, isOn: movesToCreatedFolder)
            state.setToggle(.moveToCreatedFolder, isOn: movesToCreatedFolder)
        }

        if let selectsPreviousDirectoryAfterMovingToParent = notification.userInfo?[SettingsNotificationKey.selectsPreviousDirectoryAfterMovingToParent] as? Bool {
            committedState.setToggle(
                .selectPreviousDirectoryAfterMovingToParent,
                isOn: selectsPreviousDirectoryAfterMovingToParent
            )
            state.setToggle(
                .selectPreviousDirectoryAfterMovingToParent,
                isOn: selectsPreviousDirectoryAfterMovingToParent
            )
        }

        if let confirmsBeforeCopy = notification.userInfo?[SettingsNotificationKey.confirmsBeforeCopy] as? Bool {
            committedState.setToggle(.confirmBeforeCopy, isOn: confirmsBeforeCopy)
            state.setToggle(.confirmBeforeCopy, isOn: confirmsBeforeCopy)
        }

        if let confirmsBeforeMove = notification.userInfo?[SettingsNotificationKey.confirmsBeforeMove] as? Bool {
            committedState.setToggle(.confirmBeforeMove, isOn: confirmsBeforeMove)
            state.setToggle(.confirmBeforeMove, isOn: confirmsBeforeMove)
        }

        if let confirmsBeforeTrash = notification.userInfo?[SettingsNotificationKey.confirmsBeforeTrash] as? Bool {
            committedState.setToggle(.confirmBeforeTrash, isOn: confirmsBeforeTrash)
            state.setToggle(.confirmBeforeTrash, isOn: confirmsBeforeTrash)
        }

        if let confirmsBeforeQuit = notification.userInfo?[SettingsNotificationKey.confirmsBeforeQuit] as? Bool {
            committedState.setToggle(.confirmBeforeQuit, isOn: confirmsBeforeQuit)
            state.setToggle(.confirmBeforeQuit, isOn: confirmsBeforeQuit)
        }

        if let allowsExternalFileDrag = notification.userInfo?[SettingsNotificationKey.allowsExternalFileDrag] as? Bool {
            committedState.setToggle(.allowExternalFileDrag, isOn: allowsExternalFileDrag)
            state.setToggle(.allowExternalFileDrag, isOn: allowsExternalFileDrag)
        }

        if let treatZipAsDirectory = notification.userInfo?[SettingsNotificationKey.treatZipAsDirectory] as? Bool {
            committedState.setToggle(.treatZipAsDirectory, isOn: treatZipAsDirectory)
            state.setToggle(.treatZipAsDirectory, isOn: treatZipAsDirectory)
        }

        if let fileOperationDetailLogLimit = notification.userInfo?[SettingsNotificationKey.fileOperationDetailLogLimit] as? Int {
            committedState.setNumericValue(fileOperationDetailLogLimit, for: .fileOperationDetailLogLimit)
            state.setNumericValue(fileOperationDetailLogLimit, for: .fileOperationDetailLogLimit)
        }

        if let fileListFontSize = notification.userInfo?[SettingsNotificationKey.fileListFontSize] as? Int {
            committedState.setNumericValue(fileListFontSize, for: .fileListFontSize)
            state.setNumericValue(fileListFontSize, for: .fileListFontSize)
        }

        if let leftStartupPathMode = notification.userInfo?[SettingsNotificationKey.leftStartupPathMode] as? StartupPathMode {
            committedState.setChoice(.leftStartupPathMode, to: .startupPathMode(leftStartupPathMode))
            state.setChoice(.leftStartupPathMode, to: .startupPathMode(leftStartupPathMode))
        }

        if let returnKeyBehavior = notification.userInfo?[SettingsNotificationKey.returnKeyBehavior] as? ReturnKeyBehavior {
            committedState.setChoice(.returnKeyBehavior, to: .returnKeyBehavior(returnKeyBehavior))
            state.setChoice(.returnKeyBehavior, to: .returnKeyBehavior(returnKeyBehavior))
        }

        if let rightStartupPathMode = notification.userInfo?[SettingsNotificationKey.rightStartupPathMode] as? StartupPathMode {
            committedState.setChoice(.rightStartupPathMode, to: .startupPathMode(rightStartupPathMode))
            state.setChoice(.rightStartupPathMode, to: .startupPathMode(rightStartupPathMode))
        }

        if let leftStartupPath = notification.userInfo?[SettingsNotificationKey.leftStartupPath] as? String {
            committedState.setStartupPath(leftStartupPath, for: .leftStartupPathMode)
            state.setStartupPath(leftStartupPath, for: .leftStartupPathMode)
        }

        if let rightStartupPath = notification.userInfo?[SettingsNotificationKey.rightStartupPath] as? String {
            committedState.setStartupPath(rightStartupPath, for: .rightStartupPathMode)
            state.setStartupPath(rightStartupPath, for: .rightStartupPathMode)
        }

        if let keyBindingSet = notification.userInfo?[SettingsNotificationKey.keyBindingSet] as? KeyBindingSet {
            committedState.setKeyBindingSet(keyBindingSet)
            state.setKeyBindingSet(keyBindingSet)
        }

        if isViewLoaded, view.window?.isVisible == true {
            render()
        }
    }

    private var isPathTabSelected: Bool {
        state.selectedTab?.title == "Bookmarks"
    }

    private var isKeyBindingTabSelected: Bool {
        state.selectedTab?.title == "Keybindings"
    }

    private var isFileTypesTabSelected: Bool {
        state.selectedTab?.title == "File Types"
    }

    private var isThemeTabSelected: Bool {
        state.selectedTab?.title == "Theme"
    }

    private var hasUnappliedListEditorChanges: Bool {
        hasUnappliedSettingsListEditorChanges(
            current: currentListEditorValue,
            applied: appliedListEditorValue
        )
    }

    private var currentListEditorValue: SettingsListEditorValue? {
        if isPathTabSelected {
            return .bookmark(displayName: pathNameField.stringValue, path: pathField.stringValue)
        }
        if isFileTypesTabSelected {
            return .fileType(
                extensions: fileTypeExtensionsField.stringValue,
                isOtherExtensions: fileTypeOtherExtensionsButton.state == .on,
                applicationPath: fileTypeApplicationField.stringValue,
                color: fileTypeUsesColorButton.state == .on ? fileTypeColorWell.color.displayColor : nil
            )
        }
        return nil
    }

    private var appliedListEditorValue: SettingsListEditorValue? {
        if isPathTabSelected {
            guard state.jumpPathEntries.indices.contains(state.focusedItemIndex) else {
                return .bookmark(displayName: "", path: "")
            }
            let entry = state.jumpPathEntries[state.focusedItemIndex]
            return .bookmark(displayName: entry.displayName, path: entry.path)
        }
        if isFileTypesTabSelected {
            guard state.fileTypeAssociations.indices.contains(state.focusedItemIndex) else {
                return .fileType(extensions: "", isOtherExtensions: false, applicationPath: "", color: nil)
            }
            let association = state.fileTypeAssociations[state.focusedItemIndex]
            return .fileType(
                extensions: association.extensionsText,
                isOtherExtensions: association.isOtherExtensionsAssociation,
                applicationPath: association.applicationPath,
                color: association.color.map { $0.nsColor.displayColor }
            )
        }
        return nil
    }

    private var editorHeight: CGFloat {
        if isKeyBindingTabSelected {
            if isCapturingKeySearch { return searchedKeyStrokes.isEmpty ? 0 : 95 }
            let count = focusedCommandID.map { state.keyBindingSet.sequences(for: $0).count } ?? 0
            let detailHeight = CGFloat(min(max(count, 1), 3) * 28)
            return 96 + detailHeight + (state.keyBindingSet.conflicts().isEmpty ? 0 : 20)
        }
        if isPathTabSelected {
            return 118
        }
        if isFileTypesTabSelected {
            return 190
        }
        if isThemeTabSelected {
            return 148
        }
        return 0
    }

    private var focusedDisplayColorRole: DisplayColorRole? {
        guard isThemeTabSelected, DisplayColorRole.allCases.indices.contains(state.focusedItemIndex) else {
            return nil
        }

        return DisplayColorRole.allCases[state.focusedItemIndex]
    }

    private var focusedCommandID: CommandID? {
        guard isKeyBindingTabSelected, CommandID.allCases.indices.contains(state.focusedItemIndex) else {
            return nil
        }

        let commandID = CommandID.allCases[state.focusedItemIndex]
        return dataSource.keyBindingCommandIDs.contains(commandID) ? commandID : nil
    }

    private func addPathFromEditor() {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return
        }

        if state.addJumpPath(displayName: pathNameField.stringValue, path: path) {
            state.focusJumpPath(at: max(0, state.jumpPathEntries.count - 1))
        } else if let existingIndex = state.jumpPathEntries.firstIndex(where: { $0.normalizedPath == JumpPathEntry.normalizedPath(path) }) {
            state.focusJumpPath(at: existingIndex)
        }
        render()
    }

    private func updateSelectedPathFromEditor() {
        let path = pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return
        }

        state.updateJumpPath(at: state.focusedItemIndex, displayName: pathNameField.stringValue, path: path)
        render()
    }

    private func deleteSelectedPath() {
        guard isPathTabSelected else {
            return
        }

        state.removeJumpPath(at: state.focusedItemIndex)
        if state.focusedItemIndex >= state.jumpPathEntries.count {
            state.focusJumpPath(at: max(0, state.jumpPathEntries.count - 1))
        }
        populatePathEditorFromFocusedRow()
        render()
    }

    private func moveSelectedPath(by delta: Int) {
        guard isPathTabSelected, state.jumpPathEntries.indices.contains(state.focusedItemIndex) else {
            return
        }

        state.moveJumpPath(at: state.focusedItemIndex, by: delta)
        populatePathEditorFromFocusedRow()
        render()
    }

    private func deleteFocusedItem() {
        if isPathTabSelected {
            deleteSelectedPath()
        } else if isFileTypesTabSelected {
            deleteSelectedFileTypeAssociation()
        } else if isKeyBindingTabSelected {
            removeSelectedKeyBinding()
        } else if isThemeTabSelected {
            deleteCurrentTheme()
        }
    }

    private func beginRecordingKeyBinding() {
        guard let commandID = focusedCommandID else {
            return
        }

        if isCapturingKeySearch { clearKeyBindingSearch(shouldRefresh: false) }
        recordingCommandID = commandID
        recordedKeyStrokes = []
        tableView.isRecordingKeyBinding = true
        setCaptureInteractionActive(true)
        render()
        view.window?.makeFirstResponder(keyBindingCaptureView)
    }

    func controlTextDidChange(_ obj: Notification) {
        guard obj.object as? NSSearchField === keyBindingSearchField, !isRendering else { return }
        searchedKeyStrokes = []
        refreshKeyBindingResults()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard control === keyBindingSearchField else { return false }
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            moveItemFocus(by: -1)
        case #selector(NSResponder.moveDown(_:)):
            moveItemFocus(by: 1)
        case #selector(NSResponder.insertNewline(_:)):
            view.window?.makeFirstResponder(tableView)
        case #selector(NSResponder.cancelOperation(_:)):
            clearKeyBindingSearch()
        default:
            return false
        }
        return true
    }

    private func matchingKeyBindingCommands() -> [CommandID] {
        guard isKeyBindingTabSelected else { return CommandID.allCases }
        if !searchedKeyStrokes.isEmpty {
            let matches = Set(state.keyBindingSet.bindings(startingWith: searchedKeyStrokes).map { $0.commandID })
            return CommandID.allCases.filter { matches.contains($0) }
        }
        let items = CommandID.allCases.map { commandID in
            CommandPaletteCatalog.item(for: commandID,
                                       bindings: state.keyBindingSet.sequences(for: commandID).map(\.displayText))
        }
        return CommandPaletteSearch.results(for: keyBindingSearchField.stringValue, in: items).map(\.commandID)
    }

    private func refreshKeyBindingResults() {
        isRendering = true
        defer { isRendering = false }
        let previous = focusedCommandID
        dataSource.keyBindingSet = state.keyBindingSet
        dataSource.keyBindingCommandIDs = matchingKeyBindingCommands()
        updateKeyBindingEmptyResult()
        tableView.reloadData()
        let selected = previous.flatMap { dataSource.keyBindingCommandIDs.firstIndex(of: $0) } ??
            (dataSource.keyBindingCommandIDs.isEmpty ? nil : 0)
        if let selected,
           let commandIndex = CommandID.allCases.firstIndex(of: dataSource.keyBindingCommandIDs[selected]) {
            state.focusItem(at: commandIndex)
            tableView.selectRowIndexes(IndexSet(integer: selected), byExtendingSelection: false)
            tableView.scrollRowToVisible(selected)
        } else {
            tableView.deselectAll(nil)
        }
        updateKeyBindingDetails()
        keyBindingStatusField.stringValue = keyBindingStatusText()
        updateKeyBindingModeUI()
        keyBindingSearchButton.title = isCapturingKeySearch
            ? L10n.string("settings.keybinding.keySearchRecording") : L10n.string("settings.button.searchByKey")
        updateKeySearchCaptureDisplay()
        enforceCaptureDisabledControls()
    }

    private func updateKeyBindingEmptyResult() {
        guard isKeyBindingTabSelected, dataSource.keyBindingCommandIDs.isEmpty else {
            dataSource.keyBindingEmptyResultMessage = nil
            return
        }
        let canAssign = !searchedKeyStrokes.isEmpty
            && state.keyBindingSet.canAssign(KeyBindingSequence(searchedKeyStrokes))
        dataSource.keyBindingEmptyResultMessage = canAssign
            ? L10n.string("settings.unassigned")
            : L10n.string(searchedKeyStrokes.isEmpty
                ? "settings.keybinding.noSearchResults" : "settings.keybinding.unavailableShort")
    }

    private func searchKeyBindingStroke(_ stroke: KeyStroke) {
        searchedKeyStrokes.append(stroke)
        refreshKeyBindingResults()
    }

    private func leaveKeySearchForSelectedCommand() {
        let selectedCommand = dataSource.keyBindingCommandIDs.indices.contains(tableView.selectedRow)
            ? dataSource.keyBindingCommandIDs[tableView.selectedRow] : nil
        clearKeyBindingSearch(shouldRefresh: false)
        if let selectedCommand,
           let index = CommandID.allCases.firstIndex(of: selectedCommand) {
            state.focusItem(at: index)
        }
        render()
        view.window?.makeFirstResponder(tableView)
    }

    private func updateKeyBindingDetails() {
        let selectedSequence = keyBindingDetailDataSource.sequences.indices.contains(keyBindingDetailTable.selectedRow)
            ? keyBindingDetailDataSource.sequences[keyBindingDetailTable.selectedRow] : nil
        let sequences = focusedCommandID.map { state.keyBindingSet.sequences(for: $0) } ?? []
        if let commandID = focusedCommandID {
            keyBindingDetailLabel.stringValue = L10n.format("settings.keybinding.detailsFor", commandID.localizedTitle)
                + (sequences.isEmpty ? "  ·  " + L10n.string("settings.unassigned") : "")
        } else {
            keyBindingDetailLabel.stringValue = L10n.string("settings.keybinding.details")
        }
        keyBindingDetailDataSource.sequences = sequences
        keyBindingDetailTable.reloadData()
        let selectedIndex = selectedSequence.flatMap { sequences.firstIndex(of: $0) }
            ?? (!searchedKeyStrokes.isEmpty ? sequences.firstIndex { $0.hasPrefix(searchedKeyStrokes) } : nil)
            ?? (sequences.isEmpty ? nil : 0)
        if let selectedIndex {
            keyBindingDetailTable.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        } else {
            keyBindingDetailTable.deselectAll(nil)
        }
    }

    private func updateKeyBindingModeUI() {
        let isFunctionMode = isKeyBindingTabSelected && !isCapturingKeySearch
        let isKeyMode = isKeyBindingTabSelected && isCapturingKeySearch
        keyBindingSearchRow.isHidden = !isFunctionMode
        keyBindingSearchHeightConstraint?.constant = isFunctionMode ? 30 : 0
        keyBindingDetailLabel.isHidden = !isFunctionMode && (!isKeyMode || searchedKeyStrokes.isEmpty)
        keyBindingDetailScrollView.isHidden = !isFunctionMode
        keyBindingButtonRow.isHidden = !isFunctionMode
        keyBindingKeyActionRow.isHidden = true
        keyBindingStatusField.isHidden = isKeyMode
            ? searchedKeyStrokes.isEmpty
            : (isFunctionMode ? state.keyBindingSet.conflicts().isEmpty : true)
        let sequenceCount = focusedCommandID.map { state.keyBindingSet.sequences(for: $0).count } ?? 0
        keyBindingDetailHeightConstraint?.constant = CGFloat(min(max(sequenceCount, 1), 3) * 28)
        keyBindingMoreButton.item(at: 1)?.isEnabled = focusedCommandID != nil

        if isKeyMode && !searchedKeyStrokes.isEmpty {
            let sequence = KeyBindingSequence(searchedKeyStrokes)
            keyBindingDetailLabel.stringValue = L10n.format("settings.keybinding.keyResultTitle", sequence.displayText)
            let exact = state.keyBindingSet.bindings(startingWith: searchedKeyStrokes)
                .filter { $0.sequence.strokes == searchedKeyStrokes }
            if exact.count == 1 {
                keyBindingStatusField.stringValue = exact[0].commandID.localizedTitle
                keyBindingKeyAssignButton.title = L10n.string("settings.button.reassignKey")
                keyBindingKeyRemoveButton.isHidden = false
                keyBindingKeyActionRow.isHidden = false
            } else if exact.count > 1 {
                keyBindingStatusField.stringValue = L10n.string("settings.keybinding.duplicateAssignments")
            } else if exact.isEmpty && state.keyBindingSet.canAssign(sequence) {
                keyBindingStatusField.stringValue = L10n.string("settings.keybinding.keyUnassignedDetail")
                keyBindingKeyAssignButton.title = L10n.string("settings.button.assignCommand")
                keyBindingKeyRemoveButton.isHidden = true
                keyBindingKeyActionRow.isHidden = false
            } else if !dataSource.keyBindingCommandIDs.isEmpty {
                keyBindingStatusField.stringValue = L10n.string("settings.keybinding.keyPrefixDetail")
            } else {
                keyBindingStatusField.stringValue = L10n.string("settings.keybinding.captureUnavailable")
            }
        }
        pathEditorHeightConstraint?.constant = editorHeight
    }

    private func removeSelectedKeyBinding() {
        removeKeyBindingSequence(at: keyBindingDetailTable.selectedRow)
    }

    private func removeKeyBindingSequence(at index: Int) {
        guard let commandID = focusedCommandID,
              keyBindingDetailDataSource.sequences.indices.contains(index),
              !isCapturingKeySearch else { return }
        state.removeKeyBindingSequence(at: index, from: commandID)
        cancelRecordedKeyBinding()
        refreshKeyBindingResults()
    }

    private func presentKeyBindingAssignment(for sequence: KeyBindingSequence, replacing source: CommandID?) {
        guard let window = view.window else { return }
        let picker = KeyBindingAssignmentPicker(excluding: source, bindings: state.keyBindingSet)
        let alert = NSAlert()
        alert.messageText = L10n.format("settings.keybinding.assignmentTitle", sequence.displayText)
        alert.informativeText = L10n.string("settings.keybinding.assignmentMessage")
        alert.accessoryView = picker.view
        let assignButton = alert.addButton(withTitle: L10n.string("settings.button.assignCommandConfirm"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        picker.onCommit = { [weak assignButton] in assignButton?.performClick(nil) }
        picker.onCancel = { [weak alert] in alert?.buttons.last?.performClick(nil) }
        picker.onSelectionChange = { [weak assignButton] hasSelection in
            assignButton?.isEnabled = hasSelection
        }
        assignButton.isEnabled = picker.selectedCommandID != nil
        alert.window.initialFirstResponder = picker.searchField
        alert.beginSheetModal(for: window) { [weak self, picker] response in
            guard let self else { return }
            guard response == .alertFirstButtonReturn else {
                if self.isCapturingKeySearch {
                    self.view.window?.makeFirstResponder(self.keyBindingCaptureView)
                }
                return
            }
            guard let destination = picker.selectedCommandID else {
                return
            }
            var proposed = self.state.keyBindingSet
            guard proposed.assignSequence(sequence, to: destination, replacing: source) else {
                self.showErrorAlert(title: L10n.string("settings.alert.keyBindingConflicts.title"),
                                    message: L10n.string("settings.keybinding.assignmentConflict"))
                return
            }
            self.state.setKeyBindingSet(proposed)
            self.clearKeyBindingSearch(shouldRefresh: false)
            if let index = CommandID.allCases.firstIndex(of: destination) {
                self.state.focusItem(at: index)
            }
            self.render()
        }
    }

    private func recordKeyBindingStroke(_ stroke: KeyStroke) {
        guard recordingCommandID != nil else {
            return
        }

        recordedKeyStrokes.append(stroke)
        render()
    }

    private func commitRecordedKeyBinding() {
        guard let commandID = recordingCommandID, !recordedKeyStrokes.isEmpty else {
            cancelRecordedKeyBinding()
            return
        }

        state.addKeyBindingSequence(KeyBindingSequence(recordedKeyStrokes), to: commandID)
        cancelRecordedKeyBinding()
        render()
    }

    private func cancelRecordedKeyBinding() {
        let wasRecording = recordingCommandID != nil
        recordingCommandID = nil
        recordedKeyStrokes = []
        tableView.isRecordingKeyBinding = false
        if wasRecording { setCaptureInteractionActive(false) }
        if !isCapturingKeySearch {
            keyBindingCaptureView.isHidden = true
            keyBindingCaptureHeightConstraint?.constant = 0
        }
    }

    private func updateRecordingCaptureDisplay() {
        guard let commandID = recordingCommandID else { return }
        keyBindingCaptureView.isHidden = false
        keyBindingCaptureHeightConstraint?.constant = 112
        keyBindingCaptureView.update(
            strokes: recordedKeyStrokes,
            title: L10n.format("settings.keybinding.recordCaptureTitle", commandID.localizedTitle),
            status: L10n.string("settings.keybinding.recordCaptureHelp")
        )
    }

    private func resetFocusedKeyBindingToDefault() {
        guard let commandID = focusedCommandID else {
            return
        }

        state.resetKeyBindingToDefault(commandID)
        cancelRecordedKeyBinding()
        render()
    }

    private func populatePathEditorFromFocusedRow() {
        if isFileTypesTabSelected {
            populateFileTypeEditorFromFocusedRow()
            return
        }
        guard isPathTabSelected, state.jumpPathEntries.indices.contains(state.focusedItemIndex) else {
            pathNameField.stringValue = ""
            pathField.stringValue = ""
            return
        }

        let entry = state.jumpPathEntries[state.focusedItemIndex]
        pathNameField.stringValue = entry.displayName
        pathField.stringValue = entry.path
    }

    private func renderFileTypeEditor() {
        guard isFileTypesTabSelected else { return }
        fileTypeColorScopePopup.removeAllItems()
        for scope in FileTypeColorScope.allCases {
            fileTypeColorScopePopup.addItem(withTitle: scope == .fileName
                ? L10n.string("settings.fileTypes.colorScope.fileName")
                : L10n.string("settings.fileTypes.colorScope.extension"))
            fileTypeColorScopePopup.lastItem?.representedObject = scope.rawValue
        }
        fileTypeColorScopePopup.selectItem(withTitle: state.fileTypeColorScope == .fileName
            ? L10n.string("settings.fileTypes.colorScope.fileName")
            : L10n.string("settings.fileTypes.colorScope.extension"))
        populateFileTypeEditorFromFocusedRow()
    }

    private func populateFileTypeEditorFromFocusedRow() {
        guard state.fileTypeAssociations.indices.contains(state.focusedItemIndex) else {
            fileTypeExtensionsField.stringValue = ""
            fileTypeOtherExtensionsButton.state = .off
            fileTypeExtensionsField.isEnabled = true
            fileTypeApplicationField.stringValue = ""
            fileTypeUsesColorButton.state = .off
            fileTypeColorWell.isEnabled = false
            return
        }
        let association = state.fileTypeAssociations[state.focusedItemIndex]
        fileTypeExtensionsField.stringValue = association.extensionsText
        fileTypeOtherExtensionsButton.state = association.isOtherExtensionsAssociation ? .on : .off
        fileTypeExtensionsField.isEnabled = !association.isOtherExtensionsAssociation
        fileTypeApplicationField.stringValue = association.applicationPath
        fileTypeUsesColorButton.state = association.color == nil ? .off : .on
        fileTypeColorWell.isEnabled = association.color != nil
        if let color = association.color { fileTypeColorWell.color = color.nsColor }
    }

    @objc private func chooseFileTypeApplication(_ sender: NSButton) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        fileTypeApplicationField.stringValue = url.path
    }

    @objc private func fileTypeColorChanged(_ sender: Any) {
        fileTypeColorWell.isEnabled = fileTypeUsesColorButton.state == .on
    }

    @objc private func fileTypeOtherExtensionsChanged(_ sender: NSButton) {
        let isOtherExtensions = sender.state == .on
        fileTypeExtensionsField.isEnabled = !isOtherExtensions
        if isOtherExtensions {
            fileTypeExtensionsField.stringValue = ""
        }
    }

    @objc private func fileTypeColorScopeChanged(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let scope = FileTypeColorScope(rawValue: rawValue) else { return }
        state.setFileTypeColorScope(scope)
    }

    private func fileTypeAssociationFromEditor() -> FileTypeAssociation? {
        if fileTypeOtherExtensionsButton.state == .on {
            return .other(
                applicationPath: fileTypeApplicationField.stringValue,
                color: fileTypeUsesColorButton.state == .on ? fileTypeColorWell.color.displayColor : nil
            )
        }
        let extensions = FileTypeAssociation.normalizedExtensions([fileTypeExtensionsField.stringValue])
        guard !extensions.isEmpty else { return nil }
        return FileTypeAssociation(
            extensions: extensions,
            applicationPath: fileTypeApplicationField.stringValue,
            color: fileTypeUsesColorButton.state == .on ? fileTypeColorWell.color.displayColor : nil
        )
    }

    private func addFileTypeAssociation() {
        guard let association = fileTypeAssociationFromEditor() else { return }
        let duplicates = duplicateFileTypeExtensions(afterAdding: association)
        guard duplicates.isEmpty else {
            showDuplicateFileTypeExtensionsAlert(duplicates)
            return
        }
        guard !FileTypeAssociation.hasDuplicateOtherExtensionsAssociation(
            in: state.fileTypeAssociations + [association]
        ) else {
            showDuplicateFileTypeOtherExtensionsAlert()
            return
        }
        state.addFileTypeAssociation(association)
        state.focusFileTypeAssociation(at: state.fileTypeAssociations.count - 1)
        render()
    }

    private func updateFileTypeAssociation() {
        guard let association = fileTypeAssociationFromEditor(),
              state.fileTypeAssociations.indices.contains(state.focusedItemIndex) else { return }
        let duplicates = duplicateFileTypeExtensions(afterReplacingFocusedAssociationWith: association)
        guard duplicates.isEmpty else {
            showDuplicateFileTypeExtensionsAlert(duplicates)
            return
        }
        var updatedAssociations = state.fileTypeAssociations
        updatedAssociations[state.focusedItemIndex] = association
        guard !FileTypeAssociation.hasDuplicateOtherExtensionsAssociation(in: updatedAssociations) else {
            showDuplicateFileTypeOtherExtensionsAlert()
            return
        }
        state.updateFileTypeAssociation(at: state.focusedItemIndex, with: association)
        render()
    }

    private func duplicateFileTypeExtensions(afterAdding association: FileTypeAssociation) -> [String] {
        FileTypeAssociation.duplicateExtensions(in: state.fileTypeAssociations + [association])
    }

    private func duplicateFileTypeExtensions(
        afterReplacingFocusedAssociationWith association: FileTypeAssociation
    ) -> [String] {
        guard state.fileTypeAssociations.indices.contains(state.focusedItemIndex) else { return [] }
        var associations = state.fileTypeAssociations
        associations[state.focusedItemIndex] = association
        return FileTypeAssociation.duplicateExtensions(in: associations)
    }

    private func showDuplicateFileTypeExtensionsAlert(_ extensions: [String]) {
        showErrorAlert(
            title: L10n.string("settings.alert.fileTypeExtensionConflict.title"),
            message: L10n.format(
                "settings.alert.fileTypeExtensionConflict.message",
                extensions.joined(separator: ", ")
            )
        )
    }

    private func showDuplicateFileTypeOtherExtensionsAlert() {
        showErrorAlert(
            title: L10n.string("settings.alert.fileTypeOtherExtensionsConflict.title"),
            message: L10n.string("settings.alert.fileTypeOtherExtensionsConflict.message")
        )
    }

    private func deleteSelectedFileTypeAssociation() {
        state.removeFileTypeAssociation(at: state.focusedItemIndex)
        state.focusFileTypeAssociation(at: max(0, state.fileTypeAssociations.count - 1))
        render()
    }

    private func setStartupPath(_ path: String, forItemAt row: Int) {
        guard let items = state.selectedTab?.items,
              items.indices.contains(row),
              let choiceID = items[row].choiceID else {
            return
        }

        state.setStartupPath(path, for: choiceID)
    }

    private func setNumericValue(_ value: Int, forItemAt row: Int) {
        guard let items = state.selectedTab?.items,
              items.indices.contains(row),
              let numericID = items[row].numericID else {
            return
        }

        state.setNumericValue(value, for: numericID)
    }

    @objc private func themePopupChanged(_ sender: NSPopUpButton) {
        guard !isRendering, let id = sender.selectedItem?.representedObject as? String else {
            return
        }

        state.selectDisplayTheme(id: id)
        render()
    }

    @objc private func addThemeButtonClicked(_ sender: NSButton) {
        guard let themeName = promptForThemeName() else {
            view.window?.makeFirstResponder(tableView)
            return
        }

        state.addCurrentDisplayTheme(named: themeName)
        render()
        view.window?.makeFirstResponder(tableView)
    }

    @objc private func deleteThemeButtonClicked(_ sender: NSButton) {
        deleteCurrentTheme()
    }

    @objc private func backgroundColorEditorChanged(_ sender: Any) {
        guard !isRendering,
              state.displayThemeSet.canEditSelectedTheme,
              let role = focusedDisplayColorRole else {
            return
        }

        var pair = state.displayThemeSet.selectedTheme.colorPair(for: role)
        let existingAlpha = pair.background?.paneBackgroundAlpha ?? backgroundAlphaSlider.doubleValue / 100.0
        let senderObject = sender as AnyObject
        if senderObject === usesBackgroundColorButton {
            pair.background = usesBackgroundColorButton.state == .on
                ? backgroundColorWell.color.displayColor.withAlpha(existingAlpha)
                : nil
        } else {
            pair.background = backgroundColorWell.color.displayColor.withAlpha(existingAlpha)
        }
        state.setDisplayColorPair(pair, for: role)
        render()
    }

    @objc private func backgroundAlphaEditorChanged(_ sender: NSSlider) {
        guard !isRendering,
              state.displayThemeSet.canEditSelectedTheme,
              let role = focusedDisplayColorRole,
              role.supportsBackgroundAlpha else {
            return
        }

        var pair = state.displayThemeSet.selectedTheme.colorPair(for: role)
        guard var background = pair.background else {
            return
        }

        background.alpha = sender.doubleValue / 100.0
        pair.background = background
        state.setDisplayColorPair(pair, for: role)
        render()
    }

    @objc private func foregroundColorEditorChanged(_ sender: Any) {
        guard !isRendering,
              state.displayThemeSet.canEditSelectedTheme,
              let role = focusedDisplayColorRole else {
            return
        }

        var pair = state.displayThemeSet.selectedTheme.colorPair(for: role)
        let senderObject = sender as AnyObject
        if senderObject === usesForegroundColorButton {
            pair.foreground = usesForegroundColorButton.state == .on ? foregroundColorWell.color.displayColor : nil
        } else {
            pair.foreground = foregroundColorWell.color.displayColor
        }
        state.setDisplayColorPair(pair, for: role)
        render()
    }

    private func deleteCurrentTheme() {
        guard state.displayThemeSet.canDeleteSelectedTheme else {
            return
        }

        state.deleteCurrentDisplayTheme()
        closeColorPanel()
        render()
    }

    private func promptForThemeName() -> String? {
        closeColorPanel()

        let alert = NSAlert()
        alert.messageText = L10n.string("settings.alert.addTheme.title")
        alert.informativeText = L10n.string("settings.alert.addTheme.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("settings.alert.addTheme.add"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = L10n.string("settings.alert.addTheme.placeholder")
        alert.accessoryView = inputField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        let themeName = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return themeName.isEmpty ? nil : themeName
    }

    private func renderAppearanceEditor() {
        guard isThemeTabSelected else {
            return
        }

        themePopupButton.removeAllItems()
        for theme in state.displayThemeSet.themes {
            themePopupButton.addItem(withTitle: theme.name)
            themePopupButton.lastItem?.representedObject = theme.id
        }
        if let selectedIndex = state.displayThemeSet.themes.firstIndex(where: { $0.id == state.displayThemeSet.selectedThemeID }) {
            themePopupButton.selectItem(at: selectedIndex)
        }

        let canEditSelectedTheme = state.displayThemeSet.canEditSelectedTheme
        deleteThemeButton.isEnabled = state.displayThemeSet.canDeleteSelectedTheme
        let pair = focusedDisplayColorRole.map { state.displayThemeSet.selectedTheme.colorPair(for: $0) } ?? DisplayColorPair()
        usesBackgroundColorButton.state = pair.background == nil ? .off : .on
        backgroundColorWell.color = pair.background?.nsColor ?? .textBackgroundColor
        usesBackgroundColorButton.isEnabled = canEditSelectedTheme
        backgroundColorWell.isEnabled = canEditSelectedTheme && pair.background != nil
        let supportsBackgroundAlpha = focusedDisplayColorRole?.supportsBackgroundAlpha ?? false
        let canEditBackgroundAlpha = canEditSelectedTheme && supportsBackgroundAlpha && pair.background != nil
        backgroundAlphaRow.isHidden = !supportsBackgroundAlpha
        if focusedDisplayColorRole == .message {
            backgroundAlphaLabel.stringValue = L10n.string("settings.label.messageBackgroundAlpha")
        } else {
            backgroundAlphaLabel.stringValue = L10n.string("settings.label.paneBackgroundAlpha")
        }
        backgroundAlphaSlider.doubleValue = (pair.background?.paneBackgroundAlpha ?? 1.0) * 100.0
        backgroundAlphaSlider.isEnabled = canEditBackgroundAlpha
        usesForegroundColorButton.state = pair.foreground == nil ? .off : .on
        foregroundColorWell.color = pair.foreground?.nsColor ?? .labelColor
        usesForegroundColorButton.isEnabled = canEditSelectedTheme
        foregroundColorWell.isEnabled = canEditSelectedTheme && pair.foreground != nil
    }

    private func closeColorPanel() {
        NSColorPanel.shared.orderOut(nil)
    }

    private func keyBindingStatusText() -> String {
        if let commandID = recordingCommandID {
            let sequence = KeyBindingSequence(recordedKeyStrokes).displayText
            let displaySequence = sequence.isEmpty ? L10n.string("settings.keybinding.emptyInput") : sequence
            return L10n.format("settings.keybinding.recording", commandID.localizedTitle, displaySequence)
        }

        if !searchedKeyStrokes.isEmpty || isCapturingKeySearch {
            let sequence = KeyBindingSequence(searchedKeyStrokes).displayText
            let displaySequence = sequence.isEmpty ? L10n.string("settings.keybinding.emptyInput") : sequence
            if !isCapturingKeySearch && state.keyBindingSet.canAssign(KeyBindingSequence(searchedKeyStrokes)) {
                return L10n.format("settings.keybinding.unassignedKeyStatus", displaySequence)
            }
            if !isCapturingKeySearch {
                let exact = state.keyBindingSet.bindings(startingWith: searchedKeyStrokes)
                    .contains { $0.sequence.strokes == searchedKeyStrokes }
                if !exact {
                    return L10n.format("settings.keybinding.unavailableKeyStatus", displaySequence)
                }
            }
            return L10n.format(isCapturingKeySearch
                ? "settings.keybinding.keySearchRecordingStatus" : "settings.keybinding.keySearchStatus",
                displaySequence)
        }

        let conflicts = state.keyBindingSet.conflicts()
        guard !conflicts.isEmpty else {
            return L10n.string("settings.keybinding.noConflicts")
        }

        return L10n.format("settings.keybinding.conflicts", conflicts.count)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onDismiss?()
        return false
    }

    func didDismiss() {
        closeColorPanel()
        if !isClosingAfterCommit {
            state = committedState
        }

        isClosingAfterCommit = false
    }
}

private final class SettingsTabSegmentedControl: NSSegmentedControl {
    var onMoveTabSelection: ((Int) -> Void)?
    var onMoveToItems: (() -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    init(labels: [String]) {
        super.init(frame: .zero)
        segmentCount = labels.count
        trackingMode = .selectOne
        controlSize = .large
        for (index, label) in labels.enumerated() {
            setLabel(label, forSegment: index)
            setWidth(120, forSegment: index)
        }
    }

    func setLabels(_ labels: [String]) {
        if segmentCount != labels.count {
            segmentCount = labels.count
        }

        for (index, label) in labels.enumerated() {
            setLabel(label, forSegment: index)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case SettingsKeyCode.leftArrow:
            onMoveTabSelection?(-1)
        case SettingsKeyCode.rightArrow:
            onMoveTabSelection?(1)
        case SettingsKeyCode.downArrow:
            onMoveToItems?()
        case SettingsKeyCode.returnKey, SettingsKeyCode.keypadEnter:
            onCommit?()
        case SettingsKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class ThemePreviewView: NSView {
    private struct PreviewEntry {
        let name: String
        let fileExtension: String
        let size: String
        let isDirectory: Bool
        let isSelected: Bool
        let isMarked: Bool
    }

    private let entries: [PreviewEntry] = [
        PreviewEntry(name: "Sources", fileExtension: "<DIR>", size: "", isDirectory: true, isSelected: false, isMarked: false),
        PreviewEntry(name: "templates", fileExtension: "<DIR>", size: "", isDirectory: true, isSelected: false, isMarked: false),
        PreviewEntry(name: "Tests", fileExtension: "<DIR>", size: "", isDirectory: true, isSelected: false, isMarked: true),
        PreviewEntry(name: "AGENTS", fileExtension: ".md", size: "6 KB", isDirectory: false, isSelected: false, isMarked: true),
        PreviewEntry(name: "antlers", fileExtension: "", size: "10 B", isDirectory: false, isSelected: true, isMarked: false),
        PreviewEntry(name: "Antlers", fileExtension: ".zip", size: "2.8 MB", isDirectory: false, isSelected: false, isMarked: false),
        PreviewEntry(name: "bundle", fileExtension: ".sh", size: "4 KB", isDirectory: false, isSelected: false, isMarked: false),
        PreviewEntry(name: "Package", fileExtension: ".swift", size: "690 B", isDirectory: false, isSelected: false, isMarked: false),
        PreviewEntry(name: "README", fileExtension: ".md", size: "3 KB", isDirectory: false, isSelected: false, isMarked: false)
    ]

    private var theme: DisplayTheme = .light
    private let textFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.cornerRadius = 6
        translatesAutoresizingMaskIntoConstraints = false
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(theme: DisplayTheme) {
        self.theme = theme
        needsDisplay = true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let basePair = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let baseBackground = basePair.background.map { Self.nsColor(from: $0, usesPaneAlpha: true) } ?? .textBackgroundColor
        let baseForeground = basePair.foreground.map { Self.nsColor(from: $0) } ?? .labelColor
        let focusPair = theme.resolvedFocusColorPair
        let focusColor = focusPair.background.map { Self.nsColor(from: $0) } ?? .controlAccentColor

        baseBackground.setFill()
        bounds.fill()

        let titleRect = NSRect(x: 12, y: bounds.height - 26, width: bounds.width - 24, height: 18)
        drawText("Preview", in: titleRect, color: focusPair.foreground.map { Self.nsColor(from: $0) } ?? focusColor)

        let rowHeight: CGFloat = 24
        var rowTop = bounds.height - 34
        for entry in entries {
            let rowRect = NSRect(x: 0, y: rowTop - rowHeight, width: bounds.width, height: rowHeight)
            drawRow(entry, in: rowRect, fallbackForeground: baseForeground)
            rowTop -= rowHeight
        }

        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        focusColor.setStroke()
        borderPath.lineWidth = 2
        borderPath.stroke()
    }

    private func drawRow(_ entry: PreviewEntry, in rect: NSRect, fallbackForeground: NSColor) {
        let pair = theme.resolvedColorPair(
            isSelected: entry.isSelected,
            isMarked: entry.isMarked,
            isDirectory: entry.isDirectory
        )
        if let background = pair.background {
            Self.nsColor(from: background, usesPaneAlpha: true).setFill()
            rect.fill()
        }

        let foreground = pair.foreground.map { Self.nsColor(from: $0) } ?? fallbackForeground
        let marker = entry.isMarked ? "* " : "  "
        let nameRect = NSRect(x: 12, y: rect.minY + 3, width: max(80, rect.width * 0.44), height: 18)
        let extensionRect = NSRect(x: rect.width * 0.52, y: rect.minY + 3, width: 78, height: 18)
        let sizeRect = NSRect(x: rect.width - 92, y: rect.minY + 3, width: 80, height: 18)

        drawText(marker + entry.name, in: nameRect, color: foreground)
        drawText(entry.fileExtension, in: extensionRect, color: foreground)
        drawText(entry.size, in: sizeRect, color: foreground, alignment: .right)
    }

    private func drawText(
        _ text: String,
        in rect: NSRect,
        color: NSColor,
        alignment: NSTextAlignment = .left
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: color,
            .paragraphStyle: paragraphStyle
        ]
        text.draw(in: rect, withAttributes: attributes)
    }

    private static func nsColor(from color: DisplayColor, usesPaneAlpha: Bool = false) -> NSColor {
        NSColor(
            calibratedRed: CGFloat(color.red),
            green: CGFloat(color.green),
            blue: CGFloat(color.blue),
            alpha: CGFloat(usesPaneAlpha ? color.paneBackgroundAlpha : color.alpha)
        )
    }
}

private final class SettingsTableView: NSTableView {
    var onMoveItemFocus: ((Int) -> Void)?
    var onMoveFocusedItem: ((Int) -> Void)?
    var onToggleFocusedItem: (() -> Void)?
    var onDeleteFocusedItem: (() -> Void)?
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onRecordKeyBindingStroke: ((KeyStroke) -> Void)?
    var onCommitRecordedKeyBinding: (() -> Void)?
    var onCancelRecordedKeyBinding: (() -> Void)?
    var isRecordingKeyBinding = false

    override func keyDown(with event: NSEvent) {
        if isRecordingKeyBinding {
            let stroke = KeyStroke(event: event)
            if let stroke, !stroke.modifiers.isEmpty {
                onRecordKeyBindingStroke?(stroke)
                return
            }

            switch event.keyCode {
            case SettingsKeyCode.returnKey, SettingsKeyCode.keypadEnter:
                onCommitRecordedKeyBinding?()
            case SettingsKeyCode.escape:
                onCancelRecordedKeyBinding?()
            default:
                if let stroke {
                    onRecordKeyBindingStroke?(stroke)
                } else {
                    super.keyDown(with: event)
                }
            }
            return
        }

        switch event.keyCode {
        case SettingsKeyCode.upArrow:
            if event.modifierFlags.contains(.command) {
                onMoveFocusedItem?(-1)
            } else {
                onMoveItemFocus?(-1)
            }
        case SettingsKeyCode.downArrow:
            if event.modifierFlags.contains(.command) {
                onMoveFocusedItem?(1)
            } else {
                onMoveItemFocus?(1)
            }
        case SettingsKeyCode.space:
            onToggleFocusedItem?()
        case SettingsKeyCode.delete:
            onDeleteFocusedItem?()
        case SettingsKeyCode.returnKey, SettingsKeyCode.keypadEnter:
            onCommit?()
        case SettingsKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class KeyBindingCaptureView: NSView {
    var onStroke: ((KeyStroke) -> Void)?
    var onFinish: (() -> Void)?
    var onCancel: (() -> Void)?

    private let titleField = NSTextField(labelWithString: L10n.string("settings.keybinding.captureTitle"))
    private let sequenceField = NSTextField(labelWithString: "")
    private let helpField = NSTextField(labelWithString: L10n.string("settings.keybinding.captureHelp"))

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.13).cgColor
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        layer?.cornerRadius = 9
        titleField.font = .systemFont(ofSize: 14, weight: .semibold)
        sequenceField.font = .monospacedSystemFont(ofSize: 34, weight: .bold)
        sequenceField.textColor = .controlAccentColor
        sequenceField.alignment = .left
        sequenceField.lineBreakMode = .byTruncatingMiddle
        sequenceField.maximumNumberOfLines = 1
        helpField.font = .systemFont(ofSize: 13)
        helpField.textColor = .labelColor
        for field in [titleField, sequenceField, helpField] {
            field.translatesAutoresizingMaskIntoConstraints = false
            addSubview(field)
        }
        NSLayoutConstraint.activate([
            titleField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleField.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            sequenceField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            sequenceField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            sequenceField.topAnchor.constraint(equalTo: titleField.bottomAnchor, constant: 1),
            helpField.leadingAnchor.constraint(equalTo: titleField.leadingAnchor),
            helpField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            helpField.topAnchor.constraint(equalTo: sequenceField.bottomAnchor, constant: 1)
        ])
        update(strokes: [], title: L10n.string("settings.keybinding.captureTitle"),
               status: L10n.string("settings.keybinding.captureHelp"))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(strokes: [KeyStroke], title: String, status: String) {
        titleField.stringValue = title
        helpField.stringValue = status
        sequenceField.stringValue = strokes.isEmpty
            ? L10n.string("settings.keybinding.captureWaiting")
            : KeyBindingSequence(strokes).displayText
        setAccessibilityLabel("\(titleField.stringValue): \(sequenceField.stringValue). \(status)")
    }

    override func keyDown(with event: NSEvent) {
        if let stroke = KeyStroke(event: event), !stroke.modifiers.isEmpty {
            onStroke?(stroke)
            return
        }
        switch event.keyCode {
        case SettingsKeyCode.returnKey, SettingsKeyCode.keypadEnter:
            onFinish?()
        case SettingsKeyCode.escape:
            onCancel?()
        default:
            if let stroke = KeyStroke(event: event) { onStroke?(stroke) }
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard !isHidden else { return false }
        keyDown(with: event)
        return true
    }
}

private final class KeyBindingDetailDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var sequences: [KeyBindingSequence] = []
    var onRemoveSequence: ((Int) -> Void)?

    func numberOfRows(in tableView: NSTableView) -> Int { sequences.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("keyBindingDetail")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let field = cell.textField ?? NSTextField(labelWithString: "")
        field.stringValue = sequences[row].displayText
        field.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        field.translatesAutoresizingMaskIntoConstraints = false
        let removeButton = cell.subviews.compactMap { $0 as? NSButton }.first ?? NSButton()
        removeButton.title = "−"
        removeButton.toolTip = L10n.string("settings.button.removeBinding")
        removeButton.setAccessibilityLabel(L10n.format("settings.keybinding.removeSequence", sequences[row].displayText))
        removeButton.bezelStyle = .smallSquare
        removeButton.target = self
        removeButton.action = #selector(removeSequenceClicked(_:))
        removeButton.tag = row
        removeButton.translatesAutoresizingMaskIntoConstraints = false
        if field.superview == nil {
            cell.addSubview(field)
            cell.addSubview(removeButton)
            cell.textField = field
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                field.trailingAnchor.constraint(lessThanOrEqualTo: removeButton.leadingAnchor, constant: -8),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                removeButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                removeButton.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                removeButton.widthAnchor.constraint(equalToConstant: 24)
            ])
        }
        return cell
    }

    @objc private func removeSequenceClicked(_ sender: NSButton) {
        onRemoveSequence?(sender.tag)
    }
}

final class KeyBindingAssignmentTableView: NSTableView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case SettingsKeyCode.returnKey, SettingsKeyCode.keypadEnter:
            onCommit?()
        case SettingsKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

final class KeyBindingAssignmentPicker: NSObject, NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {
    let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 300))
    let searchField = NSSearchField()
    let tableView = KeyBindingAssignmentTableView()
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onSelectionChange: ((Bool) -> Void)?

    private let allItems: [CommandPaletteItem]
    private var results: [CommandPaletteItem] = []

    var selectedCommandID: CommandID? {
        guard results.indices.contains(tableView.selectedRow) else { return nil }
        return results[tableView.selectedRow].commandID
    }

    init(excluding source: CommandID?, bindings: KeyBindingSet) {
        allItems = CommandID.allCases.filter { $0 != source }.map { commandID in
            CommandPaletteCatalog.item(for: commandID, bindings: bindings.sequences(for: commandID).map(\.displayText))
        }
        super.init()
        searchField.placeholderString = L10n.string("settings.keybinding.searchPlaceholder")
        searchField.delegate = self
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.setAccessibilityLabel(L10n.string("settings.keybinding.searchPlaceholder"))
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.allowsEmptySelection = true
        tableView.delegate = self
        tableView.dataSource = self
        tableView.onCommit = { [weak self] in self?.onCommit?() }
        tableView.onCancel = { [weak self] in self?.onCancel?() }
        tableView.target = self
        tableView.doubleAction = #selector(activateSelection(_:))
        let commandColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("command"))
        commandColumn.width = 310
        tableView.addTableColumn(commandColumn)
        let bindingColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("binding"))
        bindingColumn.width = 150
        tableView.addTableColumn(bindingColumn)
        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchField)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: view.topAnchor),
            searchField.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchField.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        searchField.nextKeyView = tableView
        tableView.nextKeyView = searchField
        refreshResults()
    }

    func controlTextDidChange(_ obj: Notification) { refreshResults() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        switch selector {
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1)
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1)
        case #selector(NSResponder.insertNewline(_:)):
            onCommit?()
        case #selector(NSResponder.cancelOperation(_:)):
            onCancel?()
        default:
            return false
        }
        return true
    }

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableViewSelectionDidChange(_ notification: Notification) {
        onSelectionChange?(selectedCommandID != nil)
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = results[row]
        if tableColumn?.identifier.rawValue == "binding" {
            let field = NSTextField(labelWithString: item.bindings.isEmpty
                ? L10n.string("commandPalette.unassigned") : item.bindings.joined(separator: " / "))
            field.lineBreakMode = .byTruncatingTail
            field.toolTip = field.stringValue
            return field
        }
        let cell = NSView()
        let title = NSTextField(labelWithString: item.title)
        title.font = .systemFont(ofSize: 13, weight: .medium)
        title.translatesAutoresizingMaskIntoConstraints = false
        let english = CommandPaletteSearch.englishMatchExplanation(for: searchField.stringValue, in: item)
        let descriptions = [item.englishTitle, item.category].compactMap { $0 } + english.filter {
            $0 != item.englishTitle && $0 != item.category
        }
        let detail = NSTextField(labelWithString: descriptions.joined(separator: "  ·  "))
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        detail.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(title)
        cell.addSubview(detail)
        NSLayoutConstraint.activate([
            title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
            title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 4),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1)
        ])
        return cell
    }

    @objc private func activateSelection(_ sender: NSTableView) {
        guard selectedCommandID != nil else { return }
        onCommit?()
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let next = max(0, min(results.count - 1, tableView.selectedRow + delta))
        tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func refreshResults() {
        results = CommandPaletteSearch.results(for: searchField.stringValue, in: allItems)
        tableView.reloadData()
        if !results.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            tableView.scrollRowToVisible(0)
        } else {
            tableView.deselectAll(nil)
        }
        onSelectionChange?(selectedCommandID != nil)
    }
}

private final class SettingsDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    enum Column {
        static let setting = NSUserInterfaceItemIdentifier("setting")
        static let category = NSUserInterfaceItemIdentifier("category")
        static let command = NSUserInterfaceItemIdentifier("command")
        static let bindings = NSUserInterfaceItemIdentifier("bindings")
        static let status = NSUserInterfaceItemIdentifier("status")
        static let bookmarkShortcut = NSUserInterfaceItemIdentifier("bookmarkShortcut")
        static let bookmarkName = NSUserInterfaceItemIdentifier("bookmarkName")
        static let bookmarkPath = NSUserInterfaceItemIdentifier("bookmarkPath")
        static let fileTypeExtensions = NSUserInterfaceItemIdentifier("fileTypeExtensions")
        static let fileTypeApplication = NSUserInterfaceItemIdentifier("fileTypeApplication")
        static let fileTypeColor = NSUserInterfaceItemIdentifier("fileTypeColor")
    }

    var mode: SettingsDataSourceMode = .settings
    var items: [SettingsItem] = []
    var jumpPathEntries: [JumpPathEntry] = []
    var fileTypeAssociations: [FileTypeAssociation] = []
    var keyBindingSet: KeyBindingSet = .default
    var keyBindingCommandIDs: [CommandID] = CommandID.allCases
    var keyBindingEmptyResultMessage: String?
    var displayTheme: DisplayTheme = .light
    var incrementalSearchPriority = false
    var showsCommandPaletteButton = true
    var showsPreviewPane = false
    var showsHiddenFiles = false
    var usesAlternatingRowBackgrounds = false
    var showsFileIcons = true
    var showsFileTagColors = true
    var showsFileExtensionsSeparately = true
    var showsMultiStrokeKeyCandidates = true
    var movesCursorAfterMarking = true
    var movesToCreatedFolder = true
    var selectsPreviousDirectoryAfterMovingToParent = true
    var confirmsBeforeCopy = true
    var confirmsBeforeMove = true
    var confirmsBeforeTrash = true
    var confirmsBeforeQuit = true
    var allowsExternalFileDrag = false
    var treatZipAsDirectory = false
    var fileOperationDetailLogLimit = 10
    var fileListFontSize = FileListFontSize.standard
    var appLanguage: AppLanguage = .system
    var previewPanePosition: PreviewPanePosition = .right
    var returnKeyBehavior: ReturnKeyBehavior = .openSelectedDirectory
    var incrementalSearchMatchMode: IncrementalSearchMatchMode = .prefix
    var leftStartupPathMode: StartupPathMode = .previous
    var rightStartupPathMode: StartupPathMode = .previous
    var leftStartupPath = ""
    var rightStartupPath = ""
    var onSelectionChange: ((Int) -> Void)?
    var onToggleItem: ((Int) -> Void)?
    var onChoiceChange: ((Int, SettingsChoiceValue) -> Void)?
    var onStartupPathChange: ((Int, String) -> Void)?
    var onNumericValueChange: ((Int, Int) -> Void)?

    func numberOfRows(in tableView: NSTableView) -> Int {
        switch mode {
        case .settings:
            return items.count
        case .jumpPaths:
            return jumpPathEntries.count
        case .fileTypes:
            return fileTypeAssociations.count
        case .keyBindings:
            return keyBindingCommandIDs.isEmpty && keyBindingEmptyResultMessage != nil
                ? 1 : keyBindingCommandIDs.count
        case .appearance:
            return DisplayColorRole.allCases.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < numberOfRows(in: tableView) else {
            return nil
        }

        if mode == .keyBindings {
            if keyBindingCommandIDs.isEmpty {
                return keyBindingEmptyResultCell(tableView: tableView, tableColumn: tableColumn)
            }
            return keyBindingCell(tableView: tableView, tableColumn: tableColumn, row: row)
        }
        if mode == .appearance {
            return appearanceCell(tableView: tableView, row: row)
        }
        if mode == .jumpPaths {
            return jumpPathCell(tableView: tableView, tableColumn: tableColumn, row: row)
        }
        if mode == .fileTypes {
            return fileTypeCell(tableView: tableView, tableColumn: tableColumn, row: row)
        }

        let identifier = NSUserInterfaceItemIdentifier("settingCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        let checkbox = cell.viewWithTag(SettingsViewTag.checkbox) as? NSButton ?? NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleCheckbox(_:)))
        let popupButton = cell.viewWithTag(SettingsViewTag.popupButton) as? NSPopUpButton ?? NSPopUpButton(frame: .zero, pullsDown: false)
        let startupPathField = cell.viewWithTag(SettingsViewTag.startupPathField) as? NSTextField ?? NSTextField(string: "")
        let numericField = cell.viewWithTag(SettingsViewTag.numericField) as? NSTextField ?? NSTextField(string: "")
        let helpField = cell.viewWithTag(SettingsViewTag.helpField) as? NSTextField ?? NSTextField(labelWithString: "")
        let controlStackIdentifier = NSUserInterfaceItemIdentifier("settingControlStack")
        let controlStack = cell.subviews.first {
            $0.identifier == controlStackIdentifier
        } as? NSStackView ?? NSStackView()
        let labelStackIdentifier = NSUserInterfaceItemIdentifier("settingLabelStack")
        let labelStack = cell.subviews.first {
            $0.identifier == labelStackIdentifier
        } as? NSStackView ?? NSStackView()

        textField.stringValue = cellTitle(for: row)
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.tag = SettingsViewTag.checkbox
        checkbox.target = self
        checkbox.action = #selector(toggleCheckbox(_:))
        checkbox.isHidden = toggleID(for: row) == nil
        checkbox.state = checkboxState(for: row)
        popupButton.translatesAutoresizingMaskIntoConstraints = false
        popupButton.tag = SettingsViewTag.popupButton
        popupButton.target = self
        popupButton.action = #selector(choicePopupChanged(_:))
        configureChoicePopup(popupButton, for: row)
        startupPathField.translatesAutoresizingMaskIntoConstraints = false
        startupPathField.tag = SettingsViewTag.startupPathField
        startupPathField.placeholderString = L10n.string("settings.placeholder.startupPath")
        startupPathField.target = self
        startupPathField.action = #selector(startupPathFieldChanged(_:))
        startupPathField.delegate = self
        configureStartupPathField(startupPathField, for: row)
        numericField.translatesAutoresizingMaskIntoConstraints = false
        numericField.tag = SettingsViewTag.numericField
        numericField.target = self
        numericField.action = #selector(numericFieldChanged(_:))
        numericField.delegate = self
        numericField.alignment = .right
        configureNumericField(numericField, for: row)
        helpField.translatesAutoresizingMaskIntoConstraints = false
        helpField.tag = SettingsViewTag.helpField
        helpField.font = .systemFont(ofSize: 11)
        helpField.textColor = .secondaryLabelColor
        helpField.lineBreakMode = .byWordWrapping
        helpField.maximumNumberOfLines = 2
        helpField.usesSingleLineMode = false
        configureHelpField(helpField, for: row)
        controlStack.orientation = .vertical
        controlStack.alignment = .trailing
        controlStack.spacing = 4
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        controlStack.identifier = controlStackIdentifier
        controlStack.isHidden = choiceID(for: row) == nil && numericID(for: row) == nil
        labelStack.orientation = .vertical
        labelStack.alignment = .leading
        labelStack.spacing = 2
        labelStack.translatesAutoresizingMaskIntoConstraints = false
        labelStack.identifier = labelStackIdentifier

        if textField.superview == nil {
            cell.addSubview(checkbox)
            labelStack.addArrangedSubview(textField)
            labelStack.addArrangedSubview(helpField)
            cell.addSubview(labelStack)
            controlStack.addArrangedSubview(popupButton)
            controlStack.addArrangedSubview(startupPathField)
            controlStack.addArrangedSubview(numericField)
            cell.addSubview(controlStack)
            cell.textField = textField
            cell.identifier = identifier

            NSLayoutConstraint.activate([
                checkbox.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                labelStack.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                labelStack.trailingAnchor.constraint(lessThanOrEqualTo: controlStack.leadingAnchor, constant: -10),
                labelStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                controlStack.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                controlStack.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                controlStack.widthAnchor.constraint(equalToConstant: 240),
                popupButton.widthAnchor.constraint(equalTo: controlStack.widthAnchor),
                startupPathField.widthAnchor.constraint(equalTo: controlStack.widthAnchor),
                numericField.widthAnchor.constraint(equalTo: controlStack.widthAnchor)
            ])
        }

        return cell
    }

    private func jumpPathCell(
        tableView: NSTableView,
        tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("jumpPathCell.\(tableColumn?.identifier.rawValue ?? "unknown")")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        let entry = jumpPathEntries[row]

        switch tableColumn?.identifier {
        case Column.bookmarkShortcut:
            textField.stringValue = Self.jumpPathShortcutText(for: row)
            textField.alignment = .center
        case Column.bookmarkName:
            textField.stringValue = entry.displayName
            textField.alignment = .natural
        case Column.bookmarkPath:
            textField.stringValue = entry.path
            textField.alignment = .natural
        default:
            textField.stringValue = ""
            textField.alignment = .natural
        }
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        if textField.superview == nil {
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        return cell
    }

    private static func jumpPathShortcutText(for row: Int) -> String {
        switch row {
        case 0...8:
            return String(row + 1)
        case 9:
            return "0"
        default:
            return ""
        }
    }

    private func fileTypeCell(
        tableView: NSTableView,
        tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("fileTypeCell.\(tableColumn?.identifier.rawValue ?? "unknown")")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        let association = fileTypeAssociations[row]

        switch tableColumn?.identifier {
        case Column.fileTypeExtensions:
            textField.stringValue = association.isOtherExtensionsAssociation
                ? L10n.string("settings.fileTypes.otherExtensions")
                : association.extensionsText
        case Column.fileTypeApplication:
            textField.stringValue = association.applicationPath.isEmpty
                ? L10n.string("settings.unset")
                : URL(fileURLWithPath: association.applicationPath).deletingPathExtension().lastPathComponent
        case Column.fileTypeColor:
            textField.stringValue = association.color?.hexString ?? L10n.string("settings.unset")
            textField.textColor = association.color?.nsColor ?? .secondaryLabelColor
        default:
            textField.stringValue = ""
        }
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.translatesAutoresizingMaskIntoConstraints = false

        if textField.superview == nil {
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        return cell
    }

    private func appearanceCell(tableView: NSTableView, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("appearanceCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let nameField = cell.viewWithTag(SettingsViewTag.appearanceName) as? NSTextField ?? NSTextField(labelWithString: "")
        let backgroundField = cell.viewWithTag(SettingsViewTag.appearanceBackground) as? NSTextField ?? NSTextField(labelWithString: "")
        let foregroundField = cell.viewWithTag(SettingsViewTag.appearanceForeground) as? NSTextField ?? NSTextField(labelWithString: "")
        let role = DisplayColorRole.allCases[row]
        let pair = displayTheme.colorPair(for: role)

        nameField.stringValue = role.localizedTitle
        backgroundField.stringValue = appearanceBackgroundText(for: role, pair: pair)
        foregroundField.stringValue = pair.foreground?.hexString ?? L10n.string("settings.unset")

        for field in [nameField, backgroundField, foregroundField] {
            field.lineBreakMode = .byTruncatingTail
            field.translatesAutoresizingMaskIntoConstraints = false
        }
        nameField.font = .systemFont(ofSize: 13)
        backgroundField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        foregroundField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)

        if nameField.superview == nil {
            nameField.tag = SettingsViewTag.appearanceName
            backgroundField.tag = SettingsViewTag.appearanceBackground
            foregroundField.tag = SettingsViewTag.appearanceForeground
            cell.addSubview(nameField)
            cell.addSubview(backgroundField)
            cell.addSubview(foregroundField)
            cell.textField = nameField
            cell.identifier = identifier

            NSLayoutConstraint.activate([
                nameField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                nameField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                nameField.widthAnchor.constraint(equalToConstant: 112),

                backgroundField.leadingAnchor.constraint(equalTo: nameField.trailingAnchor, constant: 12),
                backgroundField.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                backgroundField.widthAnchor.constraint(equalToConstant: 116),

                foregroundField.leadingAnchor.constraint(equalTo: backgroundField.trailingAnchor, constant: 12),
                foregroundField.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
                foregroundField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        return cell
    }

    private func appearanceBackgroundText(for role: DisplayColorRole, pair: DisplayColorPair) -> String {
        guard let backgroundColor = pair.background else {
            return L10n.string("settings.unset")
        }

        if role.supportsBackgroundAlpha {
            return L10n.format(
                "settings.appearance.backgroundWithAlpha",
                backgroundColor.hexString,
                Int(round(backgroundColor.paneBackgroundAlpha * 100.0))
            )
        }
        return backgroundColor.hexString
    }

    private func keyBindingCell(tableView: NSTableView, tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("keyBindingCell.\(tableColumn?.identifier.rawValue ?? "unknown")")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")

        textField.stringValue = keyBindingCellTitle(for: row, column: tableColumn?.identifier)
        textField.font = .systemFont(ofSize: 13)
        textField.lineBreakMode = .byTruncatingTail
        textField.alignment = .left
        textField.translatesAutoresizingMaskIntoConstraints = false

        if textField.superview == nil {
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = identifier

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        return cell
    }

    private func keyBindingEmptyResultCell(tableView: NSTableView, tableColumn: NSTableColumn?) -> NSView {
        let identifier = NSUserInterfaceItemIdentifier("keyBindingEmpty.\(tableColumn?.identifier.rawValue ?? "unknown")")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let field = cell.textField ?? NSTextField(labelWithString: "")
        field.stringValue = tableColumn?.identifier == Column.command ? keyBindingEmptyResultMessage ?? "" : ""
        field.font = .systemFont(ofSize: 13, weight: .medium)
        field.translatesAutoresizingMaskIntoConstraints = false
        if field.superview == nil {
            cell.addSubview(field)
            cell.textField = field
            cell.identifier = identifier
            NSLayoutConstraint.activate([
                field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
                field.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -8),
                field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        return cell
    }

    @objc private func toggleCheckbox(_ sender: NSButton) {
        guard let tableView = sender.enclosingTableView else {
            return
        }

        let row = tableView.row(for: sender)
        onToggleItem?(row)
    }

    @objc private func choicePopupChanged(_ sender: NSPopUpButton) {
        guard let tableView = sender.enclosingTableView,
              let value = sender.selectedItem?.representedObject as? SettingsChoiceValue else {
            return
        }

        let row = tableView.row(for: sender)
        onChoiceChange?(row, value)
    }

    @objc private func startupPathFieldChanged(_ sender: NSTextField) {
        notifyStartupPathChange(from: sender)
    }

    @objc private func numericFieldChanged(_ sender: NSTextField) {
        notifyNumericValueChange(from: sender)
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField else {
            return
        }

        switch textField.tag {
        case SettingsViewTag.startupPathField:
            notifyStartupPathChange(from: textField)
        case SettingsViewTag.numericField:
            notifyNumericValueChange(from: textField)
        default:
            return
        }
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String?
    ) -> Bool {
        guard control.tag == SettingsViewTag.numericField,
              let string else {
            return true
        }

        return string.allSatisfy(\.isNumber)
    }

    private func notifyStartupPathChange(from textField: NSTextField) {
        guard let tableView = textField.enclosingTableView else {
            return
        }

        let row = tableView.row(for: textField)
        onStartupPathChange?(row, textField.stringValue)
    }

    private func notifyNumericValueChange(from textField: NSTextField) {
        guard let tableView = textField.enclosingTableView else {
            return
        }

        let row = tableView.row(for: textField)
        onNumericValueChange?(row, Int(textField.stringValue) ?? 0)
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        if isStartupPathChoice(at: row) || isNumericItem(at: row) || hasHelp(for: row) {
            return 58
        }

        return 28
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        onSelectionChange?(tableView.selectedRow)
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        !(mode == .keyBindings && keyBindingCommandIDs.isEmpty)
    }

    private func checkboxState(for item: SettingsItem) -> NSControl.StateValue {
        switch item.toggleID {
        case .incrementalSearchPriority:
            return incrementalSearchPriority ? .on : .off
        case .showCommandPaletteButton:
            return showsCommandPaletteButton ? .on : .off
        case .showPreviewPane:
            return showsPreviewPane ? .on : .off
        case .showHiddenFiles:
            return showsHiddenFiles ? .on : .off
        case .useAlternatingRowBackgrounds:
            return usesAlternatingRowBackgrounds ? .on : .off
        case .showFileIcons:
            return showsFileIcons ? .on : .off
        case .showFileTagColors:
            return showsFileTagColors ? .on : .off
        case .showFileExtensionsSeparately:
            return showsFileExtensionsSeparately ? .on : .off
        case .showMultiStrokeKeyCandidates:
            return showsMultiStrokeKeyCandidates ? .on : .off
        case .moveCursorAfterMarking:
            return movesCursorAfterMarking ? .on : .off
        case .moveToCreatedFolder:
            return movesToCreatedFolder ? .on : .off
        case .selectPreviousDirectoryAfterMovingToParent:
            return selectsPreviousDirectoryAfterMovingToParent ? .on : .off
        case .confirmBeforeCopy:
            return confirmsBeforeCopy ? .on : .off
        case .confirmBeforeMove:
            return confirmsBeforeMove ? .on : .off
        case .confirmBeforeTrash:
            return confirmsBeforeTrash ? .on : .off
        case .confirmBeforeQuit:
            return confirmsBeforeQuit ? .on : .off
        case .allowExternalFileDrag:
            return allowsExternalFileDrag ? .on : .off
        case .treatZipAsDirectory:
            return treatZipAsDirectory ? .on : .off
        case nil:
            return .off
        }
    }

    private func checkboxState(for row: Int) -> NSControl.StateValue {
        guard mode == .settings, items.indices.contains(row) else {
            return .off
        }

        return checkboxState(for: items[row])
    }

    private func toggleID(for row: Int) -> SettingsToggleID? {
        guard mode == .settings, items.indices.contains(row) else {
            return nil
        }

        return items[row].toggleID
    }

    private func choiceID(for row: Int) -> SettingsChoiceID? {
        guard mode == .settings, items.indices.contains(row) else {
            return nil
        }

        return items[row].choiceID
    }

    private func numericID(for row: Int) -> SettingsNumericID? {
        guard mode == .settings, items.indices.contains(row) else {
            return nil
        }

        return items[row].numericID
    }

    private func configureChoicePopup(_ popupButton: NSPopUpButton, for row: Int) {
        guard let choiceID = choiceID(for: row) else {
            popupButton.isHidden = true
            popupButton.removeAllItems()
            return
        }

        popupButton.isHidden = false
        popupButton.removeAllItems()
        switch choiceID {
        case .previewPanePosition:
            for position in PreviewPanePosition.allCases {
                popupButton.addItem(withTitle: position.localizedTitle)
                popupButton.lastItem?.representedObject = SettingsChoiceValue.previewPanePosition(position)
            }
            if let selectedIndex = PreviewPanePosition.allCases.firstIndex(of: previewPanePosition) {
                popupButton.selectItem(at: selectedIndex)
            }
        case .appLanguage:
            for language in AppLanguage.allCases {
                popupButton.addItem(withTitle: language.localizedTitle)
                popupButton.lastItem?.representedObject = SettingsChoiceValue.appLanguage(language)
            }
            if let selectedIndex = AppLanguage.allCases.firstIndex(of: appLanguage) {
                popupButton.selectItem(at: selectedIndex)
            }
        case .returnKeyBehavior:
            for behavior in ReturnKeyBehavior.allCases {
                popupButton.addItem(withTitle: behavior.localizedTitle)
                popupButton.lastItem?.representedObject = SettingsChoiceValue.returnKeyBehavior(behavior)
            }
            if let selectedIndex = ReturnKeyBehavior.allCases.firstIndex(of: returnKeyBehavior) {
                popupButton.selectItem(at: selectedIndex)
            }
        case .incrementalSearchMatchMode:
            for mode in IncrementalSearchMatchMode.allCases {
                popupButton.addItem(withTitle: mode.localizedTitle)
                popupButton.lastItem?.representedObject = SettingsChoiceValue.incrementalSearchMatchMode(mode)
            }
            if let selectedIndex = IncrementalSearchMatchMode.allCases.firstIndex(of: incrementalSearchMatchMode) {
                popupButton.selectItem(at: selectedIndex)
            }
        case .leftStartupPathMode:
            configureStartupPathModePopup(popupButton, selectedMode: leftStartupPathMode)
        case .rightStartupPathMode:
            configureStartupPathModePopup(popupButton, selectedMode: rightStartupPathMode)
        }
    }

    private func configureStartupPathModePopup(_ popupButton: NSPopUpButton, selectedMode: StartupPathMode) {
        for mode in StartupPathMode.allCases {
            popupButton.addItem(withTitle: mode.localizedTitle)
            popupButton.lastItem?.representedObject = SettingsChoiceValue.startupPathMode(mode)
        }
        if let selectedIndex = StartupPathMode.allCases.firstIndex(of: selectedMode) {
            popupButton.selectItem(at: selectedIndex)
        }
    }

    private func configureStartupPathField(_ textField: NSTextField, for row: Int) {
        guard let choiceID = choiceID(for: row) else {
            textField.isHidden = true
            return
        }

        switch choiceID {
        case .leftStartupPathMode:
            textField.stringValue = leftStartupPath
            textField.isEnabled = leftStartupPathMode == .specified
            textField.isHidden = false
        case .rightStartupPathMode:
            textField.stringValue = rightStartupPath
            textField.isEnabled = rightStartupPathMode == .specified
            textField.isHidden = false
        case .appLanguage, .returnKeyBehavior, .incrementalSearchMatchMode, .previewPanePosition:
            textField.isHidden = true
        }
    }

    private func configureNumericField(_ textField: NSTextField, for row: Int) {
        guard let numericID = numericID(for: row) else {
            textField.isHidden = true
            return
        }

        switch numericID {
        case .fileOperationDetailLogLimit:
            textField.stringValue = "\(fileOperationDetailLogLimit)"
            textField.placeholderString = L10n.string("settings.help.fileOperationDetailLogLimit")
            textField.isEnabled = true
            textField.isHidden = false
        case .fileListFontSize:
            textField.stringValue = "\(fileListFontSize)"
            textField.placeholderString = L10n.string("settings.help.fileListFontSize")
            textField.isEnabled = true
            textField.isHidden = false
        }
    }

    private func configureHelpField(_ textField: NSTextField, for row: Int) {
        if let numericID = numericID(for: row) {
            switch numericID {
            case .fileOperationDetailLogLimit:
                textField.stringValue = L10n.string("settings.help.fileOperationDetailLogLimit")
            case .fileListFontSize:
                textField.stringValue = L10n.string("settings.help.fileListFontSize")
            }
            textField.isHidden = false
            return
        }

        if items.indices.contains(row), items[row].toggleID == .incrementalSearchPriority {
            textField.stringValue = L10n.string("settings.help.incrementalSearchPriority")
            textField.isHidden = false
            return
        }

        textField.isHidden = true
    }

    private func hasHelp(for row: Int) -> Bool {
        guard mode == .settings, items.indices.contains(row) else {
            return false
        }

        return numericID(for: row) != nil || items[row].toggleID == .incrementalSearchPriority
    }

    private func isStartupPathChoice(at row: Int) -> Bool {
        switch choiceID(for: row) {
        case .leftStartupPathMode?, .rightStartupPathMode?:
            return true
        default:
            return false
        }
    }

    private func isNumericItem(at row: Int) -> Bool {
        numericID(for: row) != nil
    }

    private func cellTitle(for row: Int) -> String {
        switch mode {
        case .settings:
            let item = items[row]
            return item.localizedTitle
        case .jumpPaths:
            let entry = jumpPathEntries[row]
            return "\(entry.listTitle)  —  \(entry.path)"
        case .fileTypes:
            let association = fileTypeAssociations[row]
            let application = association.applicationPath.isEmpty
                ? L10n.string("settings.unset")
                : URL(fileURLWithPath: association.applicationPath).deletingPathExtension().lastPathComponent
            let color = association.color?.hexString ?? L10n.string("settings.unset")
            return "\(association.extensionsText)  —  \(application)  —  \(color)"
        case .keyBindings:
            return keyBindingCellTitle(for: row, column: Column.command)
        case .appearance:
            let role = DisplayColorRole.allCases[row]
            let pair = displayTheme.colorPair(for: role)
            let background: String
            if let backgroundColor = pair.background {
                if role.supportsBackgroundAlpha {
                    background = L10n.format(
                        "settings.appearance.backgroundWithAlpha",
                        backgroundColor.hexString,
                        Int(round(backgroundColor.paneBackgroundAlpha * 100.0))
                    )
                } else {
                    background = backgroundColor.hexString
                }
            } else {
                background = L10n.string("settings.unset")
            }
            let foreground = pair.foreground?.hexString ?? L10n.string("settings.unset")
            return L10n.format("settings.appearance.row", role.localizedTitle, background, foreground)
        }
    }

    private func keyBindingCellTitle(for row: Int, column: NSUserInterfaceItemIdentifier?) -> String {
        let commandID = keyBindingCommandIDs[row]
        switch column {
        case Column.category:
            return commandID.category.localizedTitle
        case Column.command:
            return commandID.localizedTitle
        case Column.bindings:
            let bindings = keyBindingSet.sequences(for: commandID).map(\.displayText).joined(separator: " / ")
            return bindings.isEmpty ? L10n.string("settings.unassigned") : bindings
        case Column.status:
            return keyBindingStatus(for: commandID)
        default:
            return commandID.localizedTitle
        }
    }

    private func keyBindingStatus(for commandID: CommandID) -> String {
        let conflicts = keyBindingSet.conflicts().filter {
            $0.firstCommandID == commandID || $0.secondCommandID == commandID
        }
        guard !conflicts.isEmpty else {
            return ""
        }

        let labels = conflicts.map { conflict -> String in
            switch conflict.kind {
            case .duplicate:
                return L10n.format("settings.keybinding.status.duplicate", conflict.sequence.displayText)
            case .prefix:
                return L10n.format("settings.keybinding.status.prefix", conflict.sequence.displayText)
            }
        }
        return labels.joined(separator: ", ")
    }
}

private enum SettingsDataSourceMode {
    case settings
    case jumpPaths
    case fileTypes
    case keyBindings
    case appearance
}

private enum SettingsKeyCode {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
    static let space: UInt16 = 49
    static let delete: UInt16 = 51
}

private enum SettingsViewTag {
    static let checkbox = 1001
    static let popupButton = 1002
    static let startupPathField = 1003
    static let appearanceName = 1004
    static let appearanceBackground = 1005
    static let appearanceForeground = 1006
    static let numericField = 1007
    static let helpField = 1008
}

private extension NSView {
    var enclosingTableView: NSTableView? {
        if let tableView = self as? NSTableView {
            return tableView
        }

        return superview?.enclosingTableView
    }
}

private extension DisplayColor {
    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }

    func withAlpha(_ alpha: Double) -> DisplayColor {
        DisplayColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

private extension DisplayColorRole {
    var supportsBackgroundAlpha: Bool {
        self == .base || self == .message
    }
}

private extension NSColor {
    var displayColor: DisplayColor {
        let color = usingColorSpace(.sRGB) ?? self
        return DisplayColor(
            red: Double(color.redComponent),
            green: Double(color.greenComponent),
            blue: Double(color.blueComponent),
            alpha: Double(color.alphaComponent)
        )
    }
}
