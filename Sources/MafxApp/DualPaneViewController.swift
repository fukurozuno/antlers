import AppKit
import MafxCore

func renameCursorPosition(for fileName: String) -> Int {
    let nsFileName = fileName as NSString
    guard !nsFileName.pathExtension.isEmpty else {
        return nsFileName.length
    }

    return (nsFileName.deletingPathExtension as NSString).length
}

func makeFileNameInputField(currentName: String) -> NSTextField {
    let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 480, height: 24))
    inputField.stringValue = currentName
    inputField.usesSingleLineMode = true
    inputField.lineBreakMode = .byClipping
    inputField.cell?.wraps = false
    inputField.cell?.isScrollable = true
    return inputField
}

final class DualPaneViewController: NSViewController, NSSplitViewDelegate {
    private let listingService = DirectoryListingService()
    private let driveListingService = DriveListingService()
    private let tagService = TagService()
    private let fileOperationService = FileOperationService()
    private let fileInfoService = FileInfoService()
    private let pathCompletionService = PathCompletionService()
    private let fileSizeFormatter = FileSizeFormatter()
    private let paneWidthRatioStep = 0.05
    private let messageWindowHeightRatioStep = 0.05
    private var leftState: PaneState
    private var rightState: PaneState
    private var activePane: ActivePane = .left
    private var pendingKeySequence: PendingKeySequence?
    private var movesCursorAfterMarking = true
    private var movesToCreatedFolder = true
    private var selectsPreviousDirectoryAfterMovingToParent = true
    private var confirmsBeforeCopy = true
    private var confirmsBeforeMove = true
    private var confirmsBeforeTrash = true
    private var fileOperationDetailLogLimit = 10
    private var usesAlternatingRowBackgrounds = false
    private var showsFileIcons = true
    private var showsFileTagColors = true
    private var showsFileExtensionsSeparately = true
    private var showsMultiStrokeKeyCandidates = true
    private var returnKeyBehavior: ReturnKeyBehavior
    private var incrementalSearchMatchMode: IncrementalSearchMatchMode
    private var keyBindingSet: KeyBindingSet
    private var keymapResolver: KeymapResolver
    private let previewKeymapResolver = PreviewKeymapResolver()
    private var displayThemeSet: DisplayThemeSet
    private var fileTypeAssociations: [FileTypeAssociation] = []
    private var fileTypeColorScope: FileTypeColorScope = .fileName
    private var jumpPathEntries: [JumpPathEntry] = []
    private let jumpPathPanelController = FloatingListPanelController()
    private let driveListPanelController = FloatingListPanelController()
    private let tagListPanelController = FloatingListPanelController()
    private let navigationHistoryPanelController = FloatingListPanelController()
    private let sameNamedFileMarkPanelController = FloatingListPanelController()
    private let keyCandidatePanelController = KeyCandidatePanelController()
    private var isApplyingPaneWidth = false
    private var isApplyingMessageWindowHeight = false
    private var didApplyInitialPaneWidth = false
    private var didApplyInitialMessageWindowHeight = false

    private let leftPaneView = FilePaneView(title: L10n.string("pane.left"))
    private let rightPaneView = FilePaneView(title: L10n.string("pane.right"))
    private let rootSplitView = NSSplitView()
    private let splitView = NSSplitView()
    private let messageLogView = MessageLogView()
    private var themedBackgroundColor: NSColor {
        displayThemeSet.selectedTheme.usesContentTransparency ? .clear : .windowBackgroundColor
    }

    init(settings: AppSettings = AppSettings()) {
        leftState = PaneState(
            currentDirectory: settings.leftPaneDirectoryURL,
            sortDescriptor: settings.leftPaneSortDescriptor,
            showsHiddenFiles: settings.showsHiddenFiles,
            incrementalSearchMatchMode: settings.incrementalSearchMatchMode,
            navigationHistory: settings.leftPaneNavigationHistory
        )
        rightState = PaneState(
            currentDirectory: settings.rightPaneDirectoryURL,
            sortDescriptor: settings.rightPaneSortDescriptor,
            showsHiddenFiles: settings.showsHiddenFiles,
            incrementalSearchMatchMode: settings.incrementalSearchMatchMode,
            navigationHistory: settings.rightPaneNavigationHistory
        )
        movesCursorAfterMarking = settings.movesCursorAfterMarking
        movesToCreatedFolder = settings.movesToCreatedFolder
        selectsPreviousDirectoryAfterMovingToParent = settings.selectsPreviousDirectoryAfterMovingToParent
        confirmsBeforeCopy = settings.confirmsBeforeCopy
        confirmsBeforeMove = settings.confirmsBeforeMove
        confirmsBeforeTrash = settings.confirmsBeforeTrash
        fileOperationDetailLogLimit = settings.fileOperationDetailLogLimit
        usesAlternatingRowBackgrounds = settings.usesAlternatingRowBackgrounds
        showsFileIcons = settings.showsFileIcons
        showsFileTagColors = settings.showsFileTagColors
        showsFileExtensionsSeparately = settings.showsFileExtensionsSeparately
        showsMultiStrokeKeyCandidates = settings.showsMultiStrokeKeyCandidates
        returnKeyBehavior = settings.returnKeyBehavior
        incrementalSearchMatchMode = settings.incrementalSearchMatchMode
        keyBindingSet = settings.keyBindingSet
        keymapResolver = KeymapResolver(keyBindingSet: settings.keyBindingSet)
        displayThemeSet = settings.displayThemeSet
        fileTypeAssociations = settings.fileTypeAssociations
        fileTypeColorScope = settings.fileTypeColorScope
        jumpPathEntries = settings.jumpPathEntries
        super.init(nibName: nil, bundle: nil)
        keyCandidatePanelController.onSelect = { [weak self] candidate in
            self?.executeKeyCandidate(candidate)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = themedBackgroundColor.cgColor

        rootSplitView.isVertical = false
        rootSplitView.dividerStyle = .thin
        rootSplitView.delegate = self
        rootSplitView.translatesAutoresizingMaskIntoConstraints = false

        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.delegate = self
        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.addArrangedSubview(leftPaneView)
        splitView.addArrangedSubview(rightPaneView)

        rootSplitView.addArrangedSubview(splitView)
        rootSplitView.addArrangedSubview(messageLogView)

        container.addSubview(rootSplitView)

        NSLayoutConstraint.activate([
            rootSplitView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            rootSplitView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rootSplitView.topAnchor.constraint(equalTo: container.topAnchor),
            rootSplitView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(settingsDidChange(_:)),
            name: .settingsDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jumpPathEntriesDidChange(_:)),
            name: .jumpPathEntriesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mainWindowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        configurePaneCallbacks()
        reloadDirectories()
        render()
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        applyPaneWidthRatio()
        applyMessageWindowHeightRatio()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(self)
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if activePaneState.isPreviewing {
            handlePreviewKey(event)
            return
        }

        if pendingKeySequence != nil {
            if event.keyCode == AppKeyCode.escape {
                cancelPendingKeySequence()
            } else {
                resolveMainPaneKey(event)
            }
            return
        }

        if activePaneState.isIncrementalSearchActive
            || activePaneState.isWildcardMarkActive
            || activePaneState.isFileMaskInputActive {
            handleSearchInputKey(event)
            return
        }

        if let stroke = KeyStroke(event: event), stroke == KeyStroke(key: "Return") {
            handleReservedReturnKey()
            return
        }

        resolveMainPaneKey(event)
    }

    private func handleReservedReturnKey() {
        if activePaneState.selectedListItem?.isParentDirectoryItem == true {
            handleMainPaneCommand(.openSelectedDirectory)
            return
        }

        switch returnKeyBehavior {
        case .openSelectedDirectory:
            handleMainPaneCommand(.openSelectedDirectory)
        case .previewFileOrOpenDirectory:
            if activePaneState.selectedItem?.isDirectory == true {
                handleMainPaneCommand(.openSelectedDirectory)
            } else {
                beginActivePanePreview()
            }
        case .disabled:
            break
        }
    }

    private func resolveMainPaneKey(_ event: NSEvent) {
        guard let stroke = KeyStroke(event: event) else {
            super.keyDown(with: event)
            return
        }

        switch keymapResolver.resolve(stroke) {
        case .matched(let commandID):
            pendingKeySequence = nil
            keyCandidatePanelController.dismiss()
            handleMainPaneCommand(commandID)
        case .awaitingNextStroke(let pendingKeySequence):
            self.pendingKeySequence = pendingKeySequence
            showKeyCandidates(for: pendingKeySequence)
            render()
        case .unmatched:
            pendingKeySequence = nil
            keyCandidatePanelController.dismiss()
            render()
            super.keyDown(with: event)
        }
    }

    private func showKeyCandidates(for pendingKeySequence: PendingKeySequence) {
        guard showsMultiStrokeKeyCandidates else {
            keyCandidatePanelController.dismiss()
            return
        }

        keyCandidatePanelController.present(
            candidates: keymapResolver.candidates(for: pendingKeySequence),
            theme: displayThemeSet.selectedTheme,
            relativeTo: view.window
        )
    }

    private func cancelPendingKeySequence() {
        keymapResolver.resetPendingStrokes()
        pendingKeySequence = nil
        keyCandidatePanelController.dismiss()
        render()
    }

    private func executeKeyCandidate(_ candidate: KeyBindingCandidate) {
        guard pendingKeySequence != nil else {
            return
        }

        keymapResolver.resetPendingStrokes()
        pendingKeySequence = nil
        keyCandidatePanelController.dismiss()
        handleMainPaneCommand(candidate.commandID)
    }

    private func handleMainPaneCommand(_ commandID: CommandID) {
        switch commandID {
        case .moveSelectionUp:
            mutateActivePane { $0.moveSelection(by: -1) }
            render()
        case .moveSelectionDown:
            mutateActivePane { $0.moveSelection(by: 1) }
            render()
        case .moveSelectionPageUp:
            moveActivePaneSelectionByPage(direction: -1)
        case .moveSelectionPageDown:
            moveActivePaneSelectionByPage(direction: 1)
        case .enlargeMessageWindow:
            adjustMessageWindowDivider(by: messageWindowHeightRatioStep)
        case .shrinkMessageWindow:
            adjustMessageWindowDivider(by: -messageWindowHeightRatioStep)
        case .activateLeftPane:
            activatePane(.left)
        case .activateRightPane:
            activatePane(.right)
        case .historyBack:
            moveActivePaneBackwardInHistory()
        case .historyForward:
            moveActivePaneForwardInHistory()
        case .narrowLeftPane:
            adjustPaneDivider(by: -paneWidthRatioStep)
        case .widenLeftPane:
            adjustPaneDivider(by: paneWidthRatioStep)
        case .openSelectedDirectory:
            let didMove = mutateActivePane {
                $0.enterSelectedDirectory(
                    selectingPreviousDirectory: selectsPreviousDirectoryAfterMovingToParent,
                    using: listingService
                )
            }
            if didMove {
                appendMessage(pathChangedMessage(activePaneState.currentDirectory.path), in: activePane)
                postPaneDirectoriesDidChange()
            }
            render()
        case .openSelectedItem:
            openSelectedItem()
        case .openWithConfiguredApplication:
            openSelectedItemWithConfiguredApplication()
        case .previewSelectedFile:
            beginActivePanePreview()
        case .moveToParentDirectory:
            let didMove = mutateActivePane {
                $0.moveToParentDirectory(
                    selectingPreviousDirectory: selectsPreviousDirectoryAfterMovingToParent,
                    using: listingService
                )
            }
            if didMove {
                appendMessage(pathChangedMessage(activePaneState.currentDirectory.path), in: activePane)
                postPaneDirectoriesDidChange()
            }
            render()
        case .toggleMark:
            let delta = activePaneState.selectedListItem?.isSpecialItem == true
                ? 1
                : (movesCursorAfterMarking ? 1 : 0)
            mutateActivePane { $0.toggleMarkForSelectedItem(moveSelectionBy: delta) }
            render()
        case .toggleMarkReverse:
            let delta = movesCursorAfterMarking ? -1 : 0
            mutateActivePane { $0.toggleMarkForSelectedItem(moveSelectionBy: delta) }
            render()
        case .markRangeFromPreviousMarkedItem:
            mutateActivePane { $0.markRangeFromPreviousMarkedItemToSelectedItem() }
            render()
        case .clearMarkedItems:
            mutateActivePane {
                $0.clearMarkedItems()
                $0.reloadCurrentDirectory(using: listingService)
            }
            render(preservingScrollPositionIn: activePane)
        case .switchActivePane:
            activePane.toggle()
            render()
        case .beginWildcardMark:
            mutateActivePane { $0.beginWildcardMark() }
            render()
        case .beginFileMask:
            mutateActivePane { $0.beginFileMaskInput() }
            render()
        case .beginIncrementalSearch:
            mutateActivePane { $0.beginIncrementalSearch() }
            render()
        case .beginDirectPathInput:
            promptAndMoveToDirectPath()
        case .showNavigationHistory:
            showNavigationHistory()
        case .invertMarkedFiles:
            mutateActivePane { $0.invertMarkedFiles(includingDirectories: false) }
            render()
        case .invertMarkedFilesIncludingDirectories:
            mutateActivePane { $0.invertMarkedFiles(includingDirectories: true) }
            render()
        case .showSameNamedFileMarkOptions:
            showSameNamedFileMarkOptions()
        case .showSelectedItemInfo:
            showSelectedItemInfo()
        case .copyFileNamesToClipboard:
            copyActivePaneItemsToClipboard(format: .fileName)
        case .copyDirectoryPathsToClipboard:
            copyActivePaneItemsToClipboard(format: .directoryPath)
        case .copyFullPathsToClipboard:
            copyActivePaneItemsToClipboard(format: .fullPath)
        case .copyMarkedItems:
            copyMarkedItemsToOppositePane()
        case .moveMarkedItems:
            moveMarkedItemsToOppositePane()
        case .trashMarkedItems:
            trashMarkedItems()
        case .renameSelectedItem:
            promptAndRenameSelectedItem()
        case .copySelectedItemWithNewName:
            promptAndCopySelectedItemWithNewName()
        case .showContextMenu:
            showContextMenu()
        case .syncActivePaneToOpposite:
            syncPanePathToOppositeDirection(isReversed: false)
            render()
        case .syncOppositePaneToActive:
            syncPanePathToOppositeDirection(isReversed: true)
            render()
        case .showJumpPathList:
            showJumpPathList()
        case .createFolder:
            promptAndCreateFolder()
        case .showDriveList:
            showDriveList()
        case .showTagFilterList:
            showTagFilterList()
        case .showTagEditList:
            showTagEditList()
        case .toggleHiddenFiles:
            toggleHiddenFiles()
        case .openSettings:
            NotificationCenter.default.post(name: .settingsWindowRequested, object: self)
        case .quitApplication:
            NotificationCenter.default.post(name: .applicationQuitRequested, object: self)
        case .sortBySize:
            applySort(.byteSize)
        case .sortByExtension:
            applySort(.fileExtension)
        case .sortByName:
            applySort(.name)
        case .sortByModificationDate:
            applySort(.modificationDate)
        }
    }

    private func beginActivePanePreview() {
        let didBegin = mutateActivePane {
            $0.beginPreviewForSelectedFile(topVisibleRow: activePaneView.currentTopVisibleRow)
        }
        guard didBegin else {
            return
        }

        render()
    }

    private func endActivePanePreview() {
        let topVisibleRow = mutateActivePane { $0.endPreview() }
        guard let topVisibleRow else {
            return
        }

        activePaneView.restoreTopVisibleRow(topVisibleRow)
        render()
    }

    private func handlePreviewKey(_ event: NSEvent) {
        if event.keyCode == AppKeyCode.escape {
            endActivePanePreview()
            return
        }

        guard let stroke = KeyStroke(event: event) else {
            return
        }

        if previewKeymapResolver.resolve(stroke) == .endPreview {
            endActivePanePreview()
            return
        }

        switch keymapResolver.resolve(stroke) {
        case .matched(.moveSelectionUp):
            movePreviewSelection(by: -1)
        case .matched(.moveSelectionDown):
            movePreviewSelection(by: 1)
        case .matched(.moveSelectionPageUp):
            movePreviewSelection(by: -activePaneView.pageScrollRowCount)
        case .matched(.moveSelectionPageDown):
            movePreviewSelection(by: activePaneView.pageScrollRowCount)
        case .matched(.toggleMark):
            let delta = movesCursorAfterMarking ? 1 : 0
            toggleMarkForPreviewedFile(moveSelectionBy: delta)
        case .matched(.toggleMarkReverse):
            let delta = movesCursorAfterMarking ? -1 : 0
            toggleMarkForPreviewedFile(moveSelectionBy: delta)
        case .matched(.markRangeFromPreviousMarkedItem):
            mutateActivePane { $0.markRangeFromPreviousMarkedItemToSelectedItem() }
            render()
        case .matched, .awaitingNextStroke(_), .unmatched:
            keymapResolver.resetPendingStrokes()
        }
    }

    private func movePreviewSelection(by delta: Int) {
        guard delta != 0 else {
            return
        }

        mutateActivePane { _ = $0.movePreviewSelection(by: delta) }
        render()
    }

    private func toggleMarkForPreviewedFile(moveSelectionBy delta: Int) {
        mutateActivePane { $0.toggleMarkForPreviewedFile(moveSelectionBy: delta) }
        render()
    }

    private func handleSearchInputKey(_ event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            finishSearchInput(in: activePane, shouldCommit: true)
        case AppKeyCode.escape:
            finishSearchInput(in: activePane, shouldCommit: false)
        case AppKeyCode.upArrow:
            moveSearchInputSelection(by: -1, in: activePane)
        case AppKeyCode.downArrow:
            moveSearchInputSelection(by: 1, in: activePane)
        default:
            super.keyDown(with: event)
        }
    }

    private func applySort(_ criterion: FileSortCriterion) {
        mutateActivePane { $0.applySort(criterion) }
        appendMessage(L10n.format("message.sortChanged", activePaneState.sortDescriptor.localizedDisplayText), in: activePane)
        postPaneDirectoriesDidChange()
        render()
    }

    private func showSelectedItemInfo() {
        guard let selectedItem = activePaneState.selectedItem else {
            appendMessage(L10n.string("message.noInfoTarget"), in: activePane)
            render()
            return
        }

        do {
            let info = try fileInfoService.info(for: selectedItem)
            appendMessage(fileInfoMessage(for: info), in: activePane)
        } catch {
            appendMessage(L10n.format("message.fileInfoFailed", error.localizedDescription), in: activePane)
        }
        render()
    }

    private func copyActivePaneItemsToClipboard(format: ClipboardCopyFormat) {
        let targets = activePaneState.clipboardCopyTargetItems
        guard !targets.isEmpty else {
            appendMessage(L10n.string("message.noClipboardCopyTargets"), in: activePane)
            render()
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(
            format.text(for: targets, in: activePaneState.currentDirectory),
            forType: .string
        ) else {
            appendMessage(L10n.string("message.clipboardCopyFailed"), in: activePane)
            render()
            return
        }

        appendMessage(L10n.format(format.resultMessageKey, targets.count), in: activePane)
        render()
    }

    private func fileInfoMessage(for info: FileInfo) -> String {
        var parts = [
            L10n.format("message.fileInfo.name", info.name),
            L10n.format("message.fileInfo.kind", fileInfoKindName(for: info)),
            L10n.format("message.fileInfo.modified", formattedDate(info.modificationDate))
        ]

        if info.isDirectory {
            parts.append(L10n.format("message.fileInfo.directorySize", formattedDirectorySize(info.directorySize)))
        } else {
            parts.append(L10n.format("message.fileInfo.size", formattedByteSize(info.byteSize)))
        }

        if let directorySize = info.directorySize, directorySize.skippedItemCount > 0 {
            parts.append(L10n.format("message.fileInfo.skippedItems", directorySize.skippedItemCount))
        }

        return L10n.format("message.fileInfo", parts.joined(separator: " / "))
    }

    private func fileInfoKindName(for info: FileInfo) -> String {
        info.isDirectory ? L10n.string("fileKind.directory") : L10n.string("fileKind.file")
    }

    private func formattedByteSize(_ byteSize: Int64?) -> String {
        guard let byteSize else {
            return L10n.string("date.unknown")
        }

        return fileSizeFormatter.string(fromByteCount: byteSize)
    }

    private func formattedDirectorySize(_ directorySize: DirectorySize?) -> String {
        formattedByteSize(directorySize?.byteSize)
    }

    private func moveActivePaneSelectionByPage(direction: Int) {
        let visibleRowCount = activePaneView.pageScrollRowCount
        mutateActivePane {
            $0.moveSelectionByPage(direction: direction, visibleRowCount: visibleRowCount)
        }
        render()
    }

    private func toggleHiddenFiles() {
        NotificationCenter.default.post(
            name: .settingsDidChange,
            object: self,
            userInfo: [SettingsNotificationKey.showsHiddenFiles: !activePaneState.showsHiddenFiles]
        )
    }

    @objc private func jumpPathEntriesDidChange(_ notification: Notification) {
        guard let entries = notification.userInfo?[SettingsNotificationKey.jumpPathEntries] as? [JumpPathEntry] else {
            return
        }

        jumpPathEntries = entries
    }

    private func reloadDirectories() {
        leftState.loadCurrentDirectory(using: listingService)
        rightState.loadCurrentDirectory(using: listingService)
        appendMessage(pathChangedMessage(leftState.currentDirectory.path), in: .left)
        appendMessage(pathChangedMessage(rightState.currentDirectory.path), in: .right)
    }

    @objc private func settingsDidChange(_ notification: Notification) {
        if let showsHiddenFiles = notification.userInfo?[SettingsNotificationKey.showsHiddenFiles] as? Bool {
            leftState.setShowsHiddenFiles(showsHiddenFiles, using: listingService)
            rightState.setShowsHiddenFiles(showsHiddenFiles, using: listingService)
            appendMessageToBothPanes(L10n.format("message.hiddenFilesChanged", localizedOnOff(showsHiddenFiles)))
        }

        if let showsFileIcons = notification.userInfo?[SettingsNotificationKey.showsFileIcons] as? Bool {
            self.showsFileIcons = showsFileIcons
        }

        if let usesAlternatingRowBackgrounds = notification.userInfo?[SettingsNotificationKey.usesAlternatingRowBackgrounds] as? Bool {
            self.usesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
        }

        if let showsFileTagColors = notification.userInfo?[SettingsNotificationKey.showsFileTagColors] as? Bool {
            self.showsFileTagColors = showsFileTagColors
        }

        if let showsFileExtensionsSeparately = notification.userInfo?[SettingsNotificationKey.showsFileExtensionsSeparately] as? Bool {
            self.showsFileExtensionsSeparately = showsFileExtensionsSeparately
        }

        if let showsMultiStrokeKeyCandidates = notification.userInfo?[SettingsNotificationKey.showsMultiStrokeKeyCandidates] as? Bool {
            self.showsMultiStrokeKeyCandidates = showsMultiStrokeKeyCandidates
            if let pendingKeySequence {
                showKeyCandidates(for: pendingKeySequence)
            }
        }

        if let movesCursorAfterMarking = notification.userInfo?[SettingsNotificationKey.movesCursorAfterMarking] as? Bool {
            self.movesCursorAfterMarking = movesCursorAfterMarking
            appendMessageToBothPanes(L10n.format("message.cursorAfterMarkingChanged", localizedOnOff(movesCursorAfterMarking)))
        }

        if let movesToCreatedFolder = notification.userInfo?[SettingsNotificationKey.movesToCreatedFolder] as? Bool {
            self.movesToCreatedFolder = movesToCreatedFolder
            appendMessageToBothPanes(L10n.format("message.moveToCreatedFolderChanged", localizedOnOff(movesToCreatedFolder)))
        }

        if let selectsPreviousDirectoryAfterMovingToParent = notification.userInfo?[SettingsNotificationKey.selectsPreviousDirectoryAfterMovingToParent] as? Bool {
            self.selectsPreviousDirectoryAfterMovingToParent = selectsPreviousDirectoryAfterMovingToParent
            appendMessageToBothPanes(
                L10n.format(
                    "message.selectPreviousDirectoryAfterMovingToParentChanged",
                    localizedOnOff(selectsPreviousDirectoryAfterMovingToParent)
                )
            )
        }

        if let confirmsBeforeCopy = notification.userInfo?[SettingsNotificationKey.confirmsBeforeCopy] as? Bool {
            self.confirmsBeforeCopy = confirmsBeforeCopy
            appendMessageToBothPanes(L10n.format("message.confirmBeforeCopyChanged", localizedOnOff(confirmsBeforeCopy)))
        }

        if let confirmsBeforeMove = notification.userInfo?[SettingsNotificationKey.confirmsBeforeMove] as? Bool {
            self.confirmsBeforeMove = confirmsBeforeMove
            appendMessageToBothPanes(L10n.format("message.confirmBeforeMoveChanged", localizedOnOff(confirmsBeforeMove)))
        }

        if let confirmsBeforeTrash = notification.userInfo?[SettingsNotificationKey.confirmsBeforeTrash] as? Bool {
            self.confirmsBeforeTrash = confirmsBeforeTrash
            appendMessageToBothPanes(L10n.format("message.confirmBeforeTrashChanged", localizedOnOff(confirmsBeforeTrash)))
        }

        if let fileOperationDetailLogLimit = notification.userInfo?[SettingsNotificationKey.fileOperationDetailLogLimit] as? Int {
            self.fileOperationDetailLogLimit = max(0, fileOperationDetailLogLimit)
            appendMessageToBothPanes(
                L10n.format("message.fileOperationDetailLogLimitChanged", self.fileOperationDetailLogLimit)
            )
        }

        if let appLanguage = notification.userInfo?[SettingsNotificationKey.appLanguage] as? AppLanguage {
            L10n.setAppLanguage(appLanguage)
            appendMessageToBothPanes(L10n.string("message.languageChanged"))
        }

        if let returnKeyBehavior = notification.userInfo?[SettingsNotificationKey.returnKeyBehavior] as? ReturnKeyBehavior {
            self.returnKeyBehavior = returnKeyBehavior
        }

        if let incrementalSearchMatchMode = notification.userInfo?[SettingsNotificationKey.incrementalSearchMatchMode] as? IncrementalSearchMatchMode {
            self.incrementalSearchMatchMode = incrementalSearchMatchMode
            leftState.setIncrementalSearchMatchMode(incrementalSearchMatchMode)
            rightState.setIncrementalSearchMatchMode(incrementalSearchMatchMode)
        }

        if let keyBindingSet = notification.userInfo?[SettingsNotificationKey.keyBindingSet] as? KeyBindingSet {
            self.keyBindingSet = keyBindingSet
            keymapResolver = KeymapResolver(keyBindingSet: keyBindingSet)
            pendingKeySequence = nil
            keyCandidatePanelController.dismiss()
            appendMessageToBothPanes(L10n.string("message.keybindingsChanged"))
        }

        if let displayThemeSet = notification.userInfo?[SettingsNotificationKey.displayThemeSet] as? DisplayThemeSet {
            self.displayThemeSet = displayThemeSet
            appendMessageToBothPanes(L10n.string("message.appearanceChanged"))
            refreshVisibleFloatingListPanels()
        }

        if let associations = notification.userInfo?[SettingsNotificationKey.fileTypeAssociations] as? [FileTypeAssociation] {
            fileTypeAssociations = associations
        }

        if let scope = notification.userInfo?[SettingsNotificationKey.fileTypeColorScope] as? FileTypeColorScope {
            fileTypeColorScope = scope
        }

        render()
    }

    private func configurePaneCallbacks() {
        leftPaneView.onActivate = { [weak self] in
            self?.activatePane(.left)
        }
        leftPaneView.onSelectionChange = { [weak self] index in
            self?.selectItem(at: index, in: .left)
        }
        leftPaneView.onContextMenuRequest = { [weak self] point in
            self?.showContextMenu(at: point, in: .left)
        }
        leftPaneView.onIncrementalSearchQueryChange = { [weak self] query in
            self?.updateSearchInputQuery(query, in: .left)
        }
        leftPaneView.onIncrementalSearchMove = { [weak self] delta in
            self?.moveSearchInputSelection(by: delta, in: .left)
        }
        leftPaneView.onIncrementalSearchEnd = { [weak self] shouldCommit in
            self?.finishSearchInput(in: .left, shouldCommit: shouldCommit)
        }

        rightPaneView.onActivate = { [weak self] in
            self?.activatePane(.right)
        }
        rightPaneView.onSelectionChange = { [weak self] index in
            self?.selectItem(at: index, in: .right)
        }
        rightPaneView.onContextMenuRequest = { [weak self] point in
            self?.showContextMenu(at: point, in: .right)
        }
        rightPaneView.onIncrementalSearchQueryChange = { [weak self] query in
            self?.updateSearchInputQuery(query, in: .right)
        }
        rightPaneView.onIncrementalSearchMove = { [weak self] delta in
            self?.moveSearchInputSelection(by: delta, in: .right)
        }
        rightPaneView.onIncrementalSearchEnd = { [weak self] shouldCommit in
            self?.finishSearchInput(in: .right, shouldCommit: shouldCommit)
        }
    }

    private func activatePane(_ pane: ActivePane) {
        guard activePane != pane else {
            view.window?.makeFirstResponder(self)
            return
        }

        activePane = pane
        view.window?.makeFirstResponder(self)
        render()
    }

    private func selectItem(at index: Int, in pane: ActivePane) {
        switch pane {
        case .left:
            leftState.selectVisibleItem(at: index)
        case .right:
            rightState.selectVisibleItem(at: index)
        }

        view.window?.makeFirstResponder(self)
        render()
    }

    private func updateSearchInputQuery(_ query: String, in pane: ActivePane) {
        mutatePane(pane) { state in
            if state.isWildcardMarkActive {
                state.updateWildcardMarkQuery(query)
            } else if state.isFileMaskInputActive {
                state.updateFileMaskQuery(query)
            } else {
                state.updateIncrementalSearchQuery(query)
            }
        }
        render()
    }

    private func moveSearchInputSelection(by delta: Int, in pane: ActivePane) {
        mutatePane(pane) { state in
            if state.isWildcardMarkActive {
                if delta < 0 {
                    state.selectPreviousWildcardMarkMatch()
                } else {
                    state.selectNextWildcardMarkMatch()
                }
            } else if state.isFileMaskInputActive {
                if delta < 0 {
                    state.selectPreviousFileMaskInputMatch()
                } else {
                    state.selectNextFileMaskInputMatch()
                }
            } else if delta < 0 {
                state.selectPreviousIncrementalSearchMatch()
            } else {
                state.selectNextIncrementalSearchMatch()
            }
        }
        render()
    }

    private func finishSearchInput(in pane: ActivePane, shouldCommit: Bool) {
        let committedMessage = mutatePane(pane) { state -> String? in
            if state.isWildcardMarkActive {
                if shouldCommit {
                    let query = state.wildcardMarkQuery
                    state.markWildcardMatchesAndEnd()
                    if !query.isEmpty {
                        return L10n.format("message.wildcardMarkApplied", query)
                    }
                } else {
                    state.endWildcardMark()
                }
            } else if state.isFileMaskInputActive {
                if shouldCommit {
                    state.applyFileMaskAndEnd()
                    return state.fileMaskPattern.isEmpty
                        ? L10n.string("message.fileMaskCleared")
                        : L10n.format("message.fileMaskApplied", state.fileMaskPattern)
                } else {
                    state.endFileMaskInput()
                }
            } else {
                state.endIncrementalSearch()
            }

            return nil
        }

        if let committedMessage {
            appendMessage(committedMessage, in: pane)
        }
        view.window?.makeFirstResponder(self)
        render()
    }

    private func syncPanePathToOppositeDirection(isReversed: Bool) {
        let sourcePane = isReversed ? activePane : activePane.opposite
        let destinationPane = isReversed ? activePane.opposite : activePane
        let sourceDirectory = paneState(sourcePane).currentDirectory

        mutatePane(destinationPane) { $0.moveToDirectory(sourceDirectory, using: listingService) }
        appendMessage(pathChangedMessage(sourceDirectory.path), in: destinationPane)
        postPaneDirectoriesDidChange()
    }

    private func showSameNamedFileMarkOptions() {
        let controller = SameNamedFileMarkOptionsViewController(theme: displayThemeSet.selectedTheme)
        controller.preferredContentSize = SameNamedFileMarkOptionsViewController.preferredContentSize
        controller.onApply = { [weak self] options in
            self?.markSameNamedFiles(options: options)
        }
        controller.onCancel = { [weak self] in
            self?.closeSameNamedFileMarkOptions()
        }

        sameNamedFileMarkPanelController.present(
            contentViewController: controller,
            title: L10n.string("sameNamedFile.title"),
            theme: displayThemeSet.selectedTheme,
            relativeTo: view.window,
            onDismiss: { [weak self] in
                self?.view.window?.makeFirstResponder(self)
            }
        )
        controller.focusOptions()
    }

    private func showContextMenu() {
        guard activePaneState.selectedListItem?.isParentDirectoryItem != true else {
            return
        }

        let menu = makeContextMenu()
        let anchorView = activePane == .left ? leftPaneView : rightPaneView
        anchorView.popUpContextMenu(menu)
    }

    private func showContextMenu(at point: NSPoint, in pane: ActivePane) {
        guard activePane == pane,
              activePaneState.selectedListItem?.isParentDirectoryItem != true else {
            return
        }

        let menu = makeContextMenu()
        let anchorView = pane == .left ? leftPaneView : rightPaneView
        anchorView.popUpContextMenu(menu, at: point)
    }

    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let hasSelectedItem = activePaneState.selectedItem != nil
        let hasMarkedItems = !activePaneState.markedItems.isEmpty
        let hasOperationTargets = hasSelectedItem || hasMarkedItems

        addMenuItem(L10n.string("contextMenu.open"), action: #selector(openSelectedContextMenuItem(_:)), to: menu, isEnabled: hasSelectedItem)
        addOpenWithMenu(to: menu, isEnabled: hasSelectedItem)
        addMenuItem(
            L10n.string("contextMenu.revealInFinder"),
            action: #selector(revealSelectedContextMenuItemInFinder(_:)),
            to: menu,
            isEnabled: hasSelectedItem
        )
        addMenuItem(
            L10n.string("contextMenu.copyPath"),
            action: #selector(copyPathContextMenuItemsToClipboard(_:)),
            to: menu,
            isEnabled: hasOperationTargets
        )
        menu.addItem(.separator())
        addMenuItem(L10n.string("contextMenu.copy"), action: #selector(copyContextMenuItems(_:)), to: menu, isEnabled: hasOperationTargets)
        addMenuItem(L10n.string("contextMenu.move"), action: #selector(moveContextMenuItems(_:)), to: menu, isEnabled: hasOperationTargets)
        addMenuItem(L10n.string("contextMenu.rename"), action: #selector(renameContextMenuItem(_:)), to: menu, isEnabled: hasSelectedItem)
        addMenuItem(L10n.string("contextMenu.copyWithNewName"), action: #selector(copyContextMenuItemWithNewName(_:)), to: menu, isEnabled: hasSelectedItem)
        menu.addItem(.separator())
        addMenuItem(L10n.string("contextMenu.createFolder"), action: #selector(createFolderFromContextMenu(_:)), to: menu)

        return menu
    }

    private func addMenuItem(
        _ title: String,
        action: Selector,
        to menu: NSMenu,
        isEnabled: Bool = true
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = isEnabled
        menu.addItem(item)
    }

    private func addOpenWithMenu(to menu: NSMenu, isEnabled: Bool) {
        let item = NSMenuItem(title: L10n.string("contextMenu.openWith"), action: nil, keyEquivalent: "")
        item.isEnabled = isEnabled

        let submenu = NSMenu()
        if let selectedItem = activePaneState.selectedItem, isEnabled {
            let applications = NSWorkspace.shared.urlsForApplications(toOpen: selectedItem.url).sorted {
                applicationDisplayName(for: $0).localizedStandardCompare(applicationDisplayName(for: $1)) == .orderedAscending
            }

            for applicationURL in applications {
                let applicationItem = NSMenuItem(
                    title: applicationDisplayName(for: applicationURL),
                    action: #selector(openSelectedContextMenuItemWithApplication(_:)),
                    keyEquivalent: ""
                )
                applicationItem.target = self
                applicationItem.representedObject = applicationURL
                applicationItem.image = NSWorkspace.shared.icon(forFile: applicationURL.path)
                submenu.addItem(applicationItem)
            }
        }

        if submenu.items.isEmpty {
            let emptyItem = NSMenuItem(title: L10n.string("contextMenu.noApplications"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            submenu.addItem(emptyItem)
        }

        submenu.addItem(.separator())
        let otherItem = NSMenuItem(
            title: L10n.string("contextMenu.otherApplication"),
            action: #selector(chooseApplicationForSelectedContextMenuItem(_:)),
            keyEquivalent: ""
        )
        otherItem.target = self
        otherItem.isEnabled = isEnabled
        submenu.addItem(otherItem)

        item.submenu = submenu
        menu.addItem(item)
    }

    private func applicationDisplayName(for applicationURL: URL) -> String {
        if let bundle = Bundle(url: applicationURL),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        if let bundle = Bundle(url: applicationURL),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }

        return applicationURL.deletingPathExtension().lastPathComponent
    }

    @objc private func openSelectedContextMenuItem(_ sender: NSMenuItem) {
        openSelectedItem()
        view.window?.makeFirstResponder(self)
    }

    private func openSelectedItem() {
        let didMove = mutateActivePane {
            $0.enterSelectedDirectory(
                selectingPreviousDirectory: selectsPreviousDirectoryAfterMovingToParent,
                using: listingService
            )
        }
        if didMove {
            appendMessage(pathChangedMessage(activePaneState.currentDirectory.path), in: activePane)
            postPaneDirectoriesDidChange()
            render()
            return
        }

        guard let selectedItem = activePaneState.selectedItem else {
            return
        }

        if selectedItem.isDirectory {
            render()
        } else {
            NSWorkspace.shared.open(selectedItem.url)
            appendMessage(L10n.format("message.openedItem", selectedItem.name), in: activePane)
            render()
        }
    }

    private func openSelectedItemWithConfiguredApplication() {
        guard let selectedItem = activePaneState.selectedItem, !selectedItem.isDirectory else {
            return
        }

        guard let association = fileTypeAssociations.first(where: {
            $0.matches(fileExtension: selectedItem.url.pathExtension)
        }), !association.applicationPath.isEmpty else {
            return
        }

        let applicationURL = URL(fileURLWithPath: association.applicationPath)
        NSWorkspace.shared.open(
            [selectedItem.url],
            withApplicationAt: applicationURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error == nil {
                    self.appendMessage(L10n.format("message.openedItem", selectedItem.name), in: self.activePane)
                } else {
                    self.appendMessage(L10n.format("message.configuredApplicationNotFound", applicationURL.lastPathComponent), in: self.activePane)
                }
                self.render()
            }
        }
    }

    @objc private func openSelectedContextMenuItemWithApplication(_ sender: NSMenuItem) {
        guard let selectedItem = activePaneState.selectedItem,
              let applicationURL = sender.representedObject as? URL else {
            return
        }

        open(selectedItem, withApplicationAt: applicationURL, in: activePane)
        view.window?.makeFirstResponder(self)
    }

    @objc private func chooseApplicationForSelectedContextMenuItem(_ sender: NSMenuItem) {
        guard let selectedItem = activePaneState.selectedItem else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = L10n.string("contextMenu.chooseApplication.title")
        panel.prompt = L10n.string("contextMenu.chooseApplication.prompt")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let applicationURL = panel.url else {
            view.window?.makeFirstResponder(self)
            return
        }

        open(selectedItem, withApplicationAt: applicationURL, in: activePane)
        view.window?.makeFirstResponder(self)
    }

    private func open(_ item: FileItem, withApplicationAt applicationURL: URL, in pane: ActivePane) {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([item.url], withApplicationAt: applicationURL, configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }

                if let error {
                    self.appendMessage(L10n.format("message.openWithFailed", error.localizedDescription), in: pane)
                } else {
                    self.appendMessage(
                        L10n.format(
                            "message.openedItemWithApplication",
                            item.name,
                            self.applicationDisplayName(for: applicationURL)
                        ),
                        in: pane
                    )
                }
                self.render()
            }
        }
    }

    @objc private func revealSelectedContextMenuItemInFinder(_ sender: NSMenuItem) {
        guard let selectedItem = activePaneState.selectedItem else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([selectedItem.url])
        appendMessage(L10n.format("message.revealedInFinder", selectedItem.name), in: activePane)
        render()
        view.window?.makeFirstResponder(self)
    }

    @objc private func copyPathContextMenuItemsToClipboard(_ sender: NSMenuItem) {
        copyActivePaneItemsToClipboard(format: .fullPath)
        view.window?.makeFirstResponder(self)
    }

    @objc private func copyContextMenuItems(_ sender: NSMenuItem) {
        copyContextMenuItemsToOppositePane()
    }

    @objc private func moveContextMenuItems(_ sender: NSMenuItem) {
        moveContextMenuItemsToOppositePane()
    }

    @objc private func renameContextMenuItem(_ sender: NSMenuItem) {
        promptAndRenameSelectedItem()
    }

    @objc private func copyContextMenuItemWithNewName(_ sender: NSMenuItem) {
        promptAndCopySelectedItemWithNewName()
    }

    @objc private func createFolderFromContextMenu(_ sender: NSMenuItem) {
        promptAndCreateFolder()
    }

    private func closeSameNamedFileMarkOptions() {
        sameNamedFileMarkPanelController.dismiss()
    }

    private func markSameNamedFiles(options: SameNamedFileMarkOptions) {
        closeSameNamedFileMarkOptions()

        let oppositeItems = paneState(activePane.opposite).visibleItems
        let markedCount = mutateActivePane {
            $0.markSameNamedFiles(comparedWith: oppositeItems, options: options)
        }
        appendMessage(L10n.format("message.sameNamedFilesMarked", markedCount), in: activePane)
        render()
    }

    private func showJumpPathList() {
        let controller = JumpPathListViewController(entries: jumpPathEntries, theme: displayThemeSet.selectedTheme)
        controller.preferredContentSize = JumpPathListViewController.preferredContentSize
        controller.onSelect = { [weak self] entry in
            self?.moveActivePane(to: entry)
        }
        controller.onAddCurrentPath = { [weak self] in
            self?.addCurrentPathToJumpList()
        }
        controller.onCancel = { [weak self] in
            self?.closeJumpPathList()
        }

        jumpPathPanelController.present(
            contentViewController: controller,
            title: "Jump Paths",
            theme: displayThemeSet.selectedTheme,
            relativeTo: view.window,
            onDismiss: { [weak self] in
                self?.view.window?.makeFirstResponder(self)
            }
        )
        controller.focusList()
    }

    private func closeJumpPathList() {
        jumpPathPanelController.dismiss()
    }

    private func showNavigationHistory() {
        let destinationBasePane = activePane
        let controller = NavigationHistoryViewController(
            initialPane: destinationBasePane,
            theme: displayThemeSet.selectedTheme,
            historyProvider: { [weak self] pane in
                self?.paneState(pane).navigationHistory ?? NavigationHistory()
            }
        )
        controller.preferredContentSize = NavigationHistoryViewController.preferredContentSize
        controller.onSelect = { [weak self] historyPane, index, opensInOppositePane in
            guard let self else {
                return
            }

            let destinationPane = opensInOppositePane ? destinationBasePane.opposite : destinationBasePane
            self.movePaneToHistoryPath(destinationPane, at: index, usingHistoryFrom: historyPane)
        }
        controller.onCancel = { [weak self] in
            self?.closeNavigationHistory()
        }

        navigationHistoryPanelController.present(
            contentViewController: controller,
            title: "Navigation History",
            theme: displayThemeSet.selectedTheme,
            relativeTo: view.window,
            onDismiss: { [weak self] in
                self?.view.window?.makeFirstResponder(self)
            }
        )
        controller.focusList()
    }

    private func closeNavigationHistory() {
        navigationHistoryPanelController.dismiss()
    }

    private func promptAndCreateFolder() {
        guard let folderName = promptForFolderName() else {
            view.window?.makeFirstResponder(self)
            return
        }

        createFolder(named: folderName)
        view.window?.makeFirstResponder(self)
    }

    private func promptForFolderName() -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.createFolder.title")
        alert.informativeText = L10n.string("alert.createFolder.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("alert.createFolder.create"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        inputField.placeholderString = L10n.string("alert.createFolder.placeholder")
        alert.accessoryView = inputField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func createFolder(named folderName: String) {
        do {
            let createdDirectory = try fileOperationService.createDirectory(
                named: folderName,
                in: activePaneState.currentDirectory
            )

            if movesToCreatedFolder {
                mutateActivePane { $0.moveToDirectory(createdDirectory, using: listingService) }
                appendMessage(L10n.format("message.folderCreatedAndMoved", createdDirectory.lastPathComponent), in: activePane)
                postPaneDirectoriesDidChange()
            } else {
                mutateActivePane { $0.loadCurrentDirectory(using: listingService) }
                appendMessage(L10n.format("message.folderCreated", createdDirectory.lastPathComponent), in: activePane)
            }
        } catch {
            appendMessage(L10n.format("message.createFolderFailed", error.localizedDescription), in: activePane)
        }

        render()
    }

    private func promptAndMoveToDirectPath() {
        guard let path = promptForDirectPath() else {
            view.window?.makeFirstResponder(self)
            return
        }

        guard let directory = pathCompletionService.resolvedDirectoryURL(
            for: path,
            relativeTo: activePaneState.currentDirectory
        ) else {
            appendMessage(L10n.format("message.directPathInvalid", path), in: activePane)
            render()
            view.window?.makeFirstResponder(self)
            return
        }

        mutateActivePane { $0.moveToDirectory(directory, using: listingService) }
        appendMessage(pathChangedMessage(activePaneState.currentDirectory.path), in: activePane)
        postPaneDirectoriesDidChange()
        render()
        view.window?.makeFirstResponder(self)
    }

    private func promptForDirectPath() -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.directPath.title")
        alert.informativeText = L10n.string("alert.directPath.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("alert.directPath.move"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        inputField.stringValue = activePaneState.currentDirectory.path
        inputField.placeholderString = L10n.string("alert.directPath.placeholder")

        let completionDelegate = PathInputFieldDelegate { [pathCompletionService, activePaneState] input in
            pathCompletionService.completionCandidates(for: input, relativeTo: activePaneState.currentDirectory)
        }
        inputField.delegate = completionDelegate
        alert.accessoryView = inputField

        let response = withExtendedLifetime(completionDelegate) {
            alert.runModal()
        }
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func promptAndRenameSelectedItem() {
        guard let selectedItem = activePaneState.selectedItem else {
            appendMessage(L10n.string("message.noRenameTarget"), in: activePane)
            render()
            return
        }

        guard let newName = promptForRenameName(currentName: selectedItem.name) else {
            view.window?.makeFirstResponder(self)
            return
        }

        renameSelectedItem(selectedItem, to: newName)
        view.window?.makeFirstResponder(self)
    }

    private func promptAndCopySelectedItemWithNewName() {
        guard let selectedItem = activePaneState.selectedItem else {
            appendMessage(L10n.string("message.noCopyWithNewNameTarget"), in: activePane)
            render()
            return
        }

        guard let newName = promptForCopyName(currentName: selectedItem.name) else {
            view.window?.makeFirstResponder(self)
            return
        }

        copySelectedItem(selectedItem, to: newName)
        view.window?.makeFirstResponder(self)
    }

    private func promptForRenameName(currentName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.rename.title")
        alert.informativeText = L10n.string("alert.rename.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("alert.rename.rename"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let inputField = makeFileNameInputField(currentName: currentName)
        alert.accessoryView = inputField

        DispatchQueue.main.async {
            inputField.currentEditor()?.selectedRange = NSRange(
                location: renameCursorPosition(for: currentName),
                length: 0
            )
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func promptForCopyName(currentName: String) -> String? {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.copyWithNewName.title")
        alert.informativeText = L10n.string("alert.copyWithNewName.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.string("alert.copy.copy"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        let inputField = makeFileNameInputField(currentName: currentName)
        alert.accessoryView = inputField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else {
            return nil
        }

        return inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func renameSelectedItem(_ item: FileItem, to newName: String) {
        do {
            let renamedURL = try renameItem(item, to: newName, replacingExisting: false)
            appendMessage(L10n.format("message.renamedItem", item.name, renamedURL.lastPathComponent), in: activePane)
        } catch FileOperationError.destinationAlreadyExists(let destinationURL) {
            guard promptForRenameOverwrite(destinationURL: destinationURL) else {
                appendMessage(L10n.format("message.renameSkipped", destinationURL.lastPathComponent), in: activePane)
                render()
                return
            }

            do {
                let renamedURL = try renameItem(item, to: newName, replacingExisting: true)
                appendMessage(L10n.format("message.renamedItem", item.name, renamedURL.lastPathComponent), in: activePane)
            } catch {
                appendMessage(L10n.format("message.renameFailed", error.localizedDescription), in: activePane)
            }
        } catch {
            appendMessage(L10n.format("message.renameFailed", error.localizedDescription), in: activePane)
        }

        render()
    }

    private func copySelectedItem(_ item: FileItem, to newName: String) {
        do {
            let copiedURL = try copyItem(item, to: newName, replacingExisting: false)
            appendMessage(L10n.format("message.copiedItemWithNewName", item.name, copiedURL.lastPathComponent), in: activePane)
        } catch FileOperationError.destinationAlreadyExists(let destinationURL) {
            guard destinationURL.standardizedFileURL != item.url.standardizedFileURL else {
                appendMessage(L10n.string("message.copyWithNewNameSameNameFailed"), in: activePane)
                render()
                return
            }

            guard promptForCopyOverwrite(destinationURL: destinationURL) else {
                appendMessage(L10n.format("message.copyWithNewNameSkipped", destinationURL.lastPathComponent), in: activePane)
                render()
                return
            }

            do {
                let copiedURL = try copyItem(item, to: newName, replacingExisting: true)
                appendMessage(L10n.format("message.copiedItemWithNewName", item.name, copiedURL.lastPathComponent), in: activePane)
            } catch {
                appendMessage(L10n.format("message.copyWithNewNameFailed", error.localizedDescription), in: activePane)
            }
        } catch {
            appendMessage(L10n.format("message.copyWithNewNameFailed", error.localizedDescription), in: activePane)
        }

        render()
    }

    private func renameItem(_ item: FileItem, to newName: String, replacingExisting: Bool) throws -> URL {
        let renamedURL = try fileOperationService.renameItem(
            at: item.url,
            to: newName,
            replacingExisting: replacingExisting
        )
        mutateActivePane {
            $0.loadCurrentDirectory(using: listingService)
            $0.selectItem(withURL: renamedURL)
        }
        return renamedURL
    }

    private func copyItem(_ item: FileItem, to newName: String, replacingExisting: Bool) throws -> URL {
        let copiedURL = try fileOperationService.copyItem(
            at: item.url,
            to: newName,
            replacingExisting: replacingExisting
        )
        mutateActivePane {
            $0.loadCurrentDirectory(using: listingService)
            $0.selectItem(withURL: copiedURL)
        }
        return copiedURL
    }

    private func promptForRenameOverwrite(destinationURL: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.conflict.title")
        alert.informativeText = L10n.format("alert.renameOverwrite.message", destinationURL.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("alert.conflict.replace"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func promptForCopyOverwrite(destinationURL: URL) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.conflict.title")
        alert.informativeText = L10n.format("alert.copyOverwrite.message", destinationURL.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("alert.conflict.replace"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func copyMarkedItemsToOppositePane() {
        copyItemsToOppositePane(sourceURLs: paneState(activePane).markedItems.map(\.url), emptyMessage: L10n.string("message.noMarkedCopyTargets"))
    }

    private func copyContextMenuItemsToOppositePane() {
        copyItemsToOppositePane(sourceURLs: contextMenuOperationURLs(), emptyMessage: L10n.string("message.noCopyTargets"))
    }

    private func copyItemsToOppositePane(sourceURLs: [URL], emptyMessage: String) {
        let sourcePane = activePane
        let destinationPane = activePane.opposite
        let destinationDirectory = paneState(destinationPane).currentDirectory

        guard !sourceURLs.isEmpty else {
            appendMessage(emptyMessage, in: sourcePane)
            render()
            return
        }

        if confirmsBeforeCopy, !promptForFileOperationConfirmation(
            titleKey: "alert.copy.title",
            messageKey: "alert.copy.message",
            actionKey: "alert.copy.copy",
            sourceURLs: sourceURLs,
            destinationDirectory: destinationDirectory
        ) {
            appendMessage(L10n.string("message.copyCancelled"), in: sourcePane)
            view.window?.makeFirstResponder(self)
            render()
            return
        }

        var repeatedResolution: FileCopyConflictResolution?

        do {
            let result = try fileOperationService.copyItems(at: sourceURLs, to: destinationDirectory) { [weak self] conflict in
                if let repeatedResolution {
                    return repeatedResolution
                }

                guard let self else {
                    return .skip
                }

                let promptResult = self.promptForCopyConflictResolution(conflict)
                if promptResult.appliesToRemaining {
                    repeatedResolution = promptResult.resolution
                }
                return promptResult.resolution
            }

            mutatePane(destinationPane) { $0.loadCurrentDirectory(using: listingService) }
            appendMessages(copyResultMessages(result, destinationDirectory: destinationDirectory), in: sourcePane)
        } catch {
            appendMessage(L10n.format("message.copyFailed", error.localizedDescription), in: sourcePane)
        }

        view.window?.makeFirstResponder(self)
        render()
    }

    private func promptForCopyConflictResolution(_ conflict: FileCopyConflict) -> CopyConflictPromptResult {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.conflict.title")
        alert.informativeText = copyConflictInformativeText(for: conflict)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("alert.copyConflict.copyButton"))
        alert.addButton(withTitle: L10n.string("alert.conflict.skipButton"))
        alert.addButton(withTitle: L10n.string("alert.copyConflict.copyIfNewerButton"))
        alert.addButton(withTitle: L10n.string("alert.conflict.cancelButton"))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "s"
        alert.buttons[2].keyEquivalent = "n"
        alert.buttons[3].keyEquivalent = "\u{1b}"

        let checkbox = NSButton(checkboxWithTitle: L10n.string("alert.conflict.applyToRemainingButton"), target: nil, action: nil)
        checkbox.state = .off
        checkbox.keyEquivalent = " "
        alert.accessoryView = checkbox

        let response = alert.runModal()
        let resolution: FileCopyConflictResolution
        switch response {
        case .alertFirstButtonReturn:
            resolution = .copy
        case .alertSecondButtonReturn:
            resolution = .skip
        case .alertThirdButtonReturn:
            resolution = .copyIfSourceIsNewer
        default:
            resolution = .cancel
        }

        return CopyConflictPromptResult(
            resolution: resolution,
            appliesToRemaining: checkbox.state == .on
        )
    }

    private func copyConflictInformativeText(for conflict: FileCopyConflict) -> String {
        """
        \(L10n.format("alert.copyConflict.source", conflict.sourceURL.lastPathComponent))
        \(L10n.format("alert.copyConflict.destination", conflict.destinationURL.lastPathComponent))
        \(L10n.format("alert.copyConflict.sourceModified", formattedDate(conflict.sourceModificationDate)))
        \(L10n.format("alert.copyConflict.destinationModified", formattedDate(conflict.destinationModificationDate)))
        """
    }

    private func copyResultMessages(_ result: FileCopyResult, destinationDirectory: URL) -> [String] {
        let summary: String
        if result.wasCancelled {
            summary = L10n.format(
                "message.copyCancelledResult",
                result.copiedCount,
                result.skippedCount,
                result.unprocessedCount,
                destinationDirectory.path
            )
        } else {
            summary = L10n.format("message.copyResult", result.copiedCount, result.skippedCount, destinationDirectory.path)
        }

        return [summary] + operationDetailMessages(
            from: result.itemResults,
            successOutcome: .copied,
            successMessageKey: "message.copyDetail",
            remainingSuccessKey: "message.copyDetailRemaining"
        )
    }

    private func moveMarkedItemsToOppositePane() {
        moveItemsToOppositePane(sourceURLs: paneState(activePane).markedItems.map(\.url), emptyMessage: L10n.string("message.noMarkedMoveTargets"))
    }

    private func moveContextMenuItemsToOppositePane() {
        moveItemsToOppositePane(sourceURLs: contextMenuOperationURLs(), emptyMessage: L10n.string("message.noMoveTargets"))
    }

    private func trashMarkedItems() {
        let sourcePane = activePane
        let targets = paneState(sourcePane).markedItems

        guard !targets.isEmpty else {
            appendMessage(L10n.string("message.noMarkedTrashTargets"), in: sourcePane)
            render()
            return
        }

        if confirmsBeforeTrash, !promptForTrashConfirmation(targets) {
            appendMessage(L10n.string("message.trashCancelled"), in: sourcePane)
            view.window?.makeFirstResponder(self)
            render()
            return
        }

        do {
            let result = try fileOperationService.trashItems(at: targets.map(\.url))
            mutatePane(sourcePane) {
                $0.loadCurrentDirectory(using: listingService)
                $0.clearMarkedItems()
            }
            appendMessages(trashResultMessages(result), in: sourcePane)
        } catch {
            appendMessage(L10n.format("message.trashFailed", error.localizedDescription), in: sourcePane)
        }

        view.window?.makeFirstResponder(self)
        render()
    }

    private func promptForTrashConfirmation(_ targets: [FileItem]) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.trash.title")
        alert.informativeText = trashConfirmationInformativeText(for: targets)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("settings.button.ok"))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func trashConfirmationInformativeText(for targets: [FileItem]) -> String {
        let directoryText = targets.contains { $0.isDirectory }
            ? L10n.string("alert.trash.includesDirectories.yes")
            : L10n.string("alert.trash.includesDirectories.no")
        let samplePaths = targets.prefix(5).map { $0.url.path }.joined(separator: "\n")

        var lines = [
            L10n.format("alert.trash.count", targets.count),
            directoryText,
            L10n.string("alert.trash.recursiveNotice")
        ]
        if !samplePaths.isEmpty {
            lines.append(L10n.format("alert.trash.samplePaths", samplePaths))
        }
        if targets.count > 5 {
            lines.append(L10n.format("alert.trash.remainingCount", targets.count - 5))
        }

        return lines.joined(separator: "\n")
    }

    private func moveItemsToOppositePane(sourceURLs: [URL], emptyMessage: String) {
        let sourcePane = activePane
        let destinationPane = activePane.opposite
        let destinationDirectory = paneState(destinationPane).currentDirectory

        guard !sourceURLs.isEmpty else {
            appendMessage(emptyMessage, in: sourcePane)
            render()
            return
        }

        if confirmsBeforeMove, !promptForFileOperationConfirmation(
            titleKey: "alert.move.title",
            messageKey: "alert.move.message",
            actionKey: "alert.move.move",
            sourceURLs: sourceURLs,
            destinationDirectory: destinationDirectory
        ) {
            appendMessage(L10n.string("message.moveCancelled"), in: sourcePane)
            view.window?.makeFirstResponder(self)
            render()
            return
        }

        var repeatedResolution: FileMoveConflictResolution?

        do {
            let result = try fileOperationService.moveItems(at: sourceURLs, to: destinationDirectory) { [weak self] conflict in
                if let repeatedResolution {
                    return repeatedResolution
                }

                guard let self else {
                    return .skip
                }

                let promptResult = self.promptForMoveConflictResolution(conflict)
                if promptResult.appliesToRemaining {
                    repeatedResolution = promptResult.resolution
                }
                return promptResult.resolution
            }

            mutatePane(sourcePane) { $0.loadCurrentDirectory(using: listingService) }
            mutatePane(destinationPane) { $0.loadCurrentDirectory(using: listingService) }
            appendMessages(moveResultMessages(result, destinationDirectory: destinationDirectory), in: sourcePane)
        } catch {
            appendMessage(L10n.format("message.moveFailed", error.localizedDescription), in: sourcePane)
        }

        view.window?.makeFirstResponder(self)
        render()
    }

    private func contextMenuOperationURLs() -> [URL] {
        let markedURLs = paneState(activePane).markedItems.map(\.url)
        if !markedURLs.isEmpty {
            return markedURLs
        }

        return activePaneState.selectedItem.map { [$0.url] } ?? []
    }

    private func promptForFileOperationConfirmation(
        titleKey: String,
        messageKey: String,
        actionKey: String,
        sourceURLs: [URL],
        destinationDirectory: URL
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.string(titleKey)
        alert.informativeText = fileOperationConfirmationInformativeText(
            messageKey: messageKey,
            sourceURLs: sourceURLs,
            destinationDirectory: destinationDirectory
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string(actionKey))
        alert.addButton(withTitle: L10n.string("settings.button.cancel"))
        alert.buttons[1].keyEquivalent = "\u{1b}"

        return alert.runModal() == .alertFirstButtonReturn
    }

    private func fileOperationConfirmationInformativeText(
        messageKey: String,
        sourceURLs: [URL],
        destinationDirectory: URL
    ) -> String {
        let samplePaths = sourceURLs.prefix(5).map(\.path).joined(separator: "\n")
        var lines = [
            L10n.string(messageKey),
            L10n.format("alert.operation.count", sourceURLs.count),
            L10n.format("alert.operation.destination", destinationDirectory.path)
        ]
        if !samplePaths.isEmpty {
            lines.append(L10n.format("alert.operation.samplePaths", samplePaths))
        }
        if sourceURLs.count > 5 {
            lines.append(L10n.format("alert.operation.remainingCount", sourceURLs.count - 5))
        }

        return lines.joined(separator: "\n")
    }

    private func promptForMoveConflictResolution(_ conflict: FileMoveConflict) -> MoveConflictPromptResult {
        let alert = NSAlert()
        alert.messageText = L10n.string("alert.conflict.title")
        alert.informativeText = moveConflictInformativeText(for: conflict)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.string("alert.moveConflict.moveButton"))
        alert.addButton(withTitle: L10n.string("alert.conflict.skipButton"))
        alert.addButton(withTitle: L10n.string("alert.moveConflict.moveIfNewerButton"))
        alert.addButton(withTitle: L10n.string("alert.conflict.cancelButton"))
        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "s"
        alert.buttons[2].keyEquivalent = "n"
        alert.buttons[3].keyEquivalent = "\u{1b}"

        let checkbox = NSButton(checkboxWithTitle: L10n.string("alert.conflict.applyToRemainingButton"), target: nil, action: nil)
        checkbox.state = .off
        checkbox.keyEquivalent = " "
        alert.accessoryView = checkbox

        let response = alert.runModal()
        let resolution: FileMoveConflictResolution
        switch response {
        case .alertFirstButtonReturn:
            resolution = .move
        case .alertSecondButtonReturn:
            resolution = .skip
        case .alertThirdButtonReturn:
            resolution = .moveIfSourceIsNewer
        default:
            resolution = .cancel
        }

        return MoveConflictPromptResult(
            resolution: resolution,
            appliesToRemaining: checkbox.state == .on
        )
    }

    private func moveConflictInformativeText(for conflict: FileMoveConflict) -> String {
        """
        \(L10n.format("alert.moveConflict.source", conflict.sourceURL.lastPathComponent))
        \(L10n.format("alert.moveConflict.destination", conflict.destinationURL.lastPathComponent))
        \(L10n.format("alert.moveConflict.sourceModified", formattedDate(conflict.sourceModificationDate)))
        \(L10n.format("alert.moveConflict.destinationModified", formattedDate(conflict.destinationModificationDate)))
        """
    }

    private func moveResultMessages(_ result: FileMoveResult, destinationDirectory: URL) -> [String] {
        let summary: String
        if result.wasCancelled {
            summary = L10n.format(
                "message.moveCancelledResult",
                result.movedCount,
                result.skippedCount,
                result.unprocessedCount,
                destinationDirectory.path
            )
        } else {
            summary = L10n.format("message.moveResult", result.movedCount, result.skippedCount, destinationDirectory.path)
        }

        return [summary] + operationDetailMessages(
            from: result.itemResults,
            successOutcome: .moved,
            successMessageKey: "message.moveDetail",
            remainingSuccessKey: "message.moveDetailRemaining"
        )
    }

    private func trashResultMessages(_ result: FileTrashResult) -> [String] {
        [L10n.format("message.trashResult", result.trashedCount)]
            + operationDetailMessages(
                from: result.itemResults,
                successOutcome: .trashed,
                successMessageKey: "message.trashDetail",
                remainingSuccessKey: "message.trashDetailRemaining"
            )
    }

    private func operationDetailMessages(
        from itemResults: [FileOperationItemResult],
        successOutcome: FileOperationItemOutcome,
        successMessageKey: String,
        remainingSuccessKey: String
    ) -> [String] {
        let successfulResults = itemResults.filter { $0.outcome == successOutcome }
        let skippedResults = itemResults.filter {
            if case .skipped = $0.outcome {
                return true
            }
            return false
        }
        let unprocessedResults = itemResults.filter { $0.outcome == .unprocessed }

        return limitedDetailMessages(
            for: successfulResults,
            line: { result in operationSuccessDetailMessage(result, messageKey: successMessageKey) },
            remainingKey: remainingSuccessKey
        ) + limitedDetailMessages(
            for: skippedResults,
            line: skipDetailMessage,
            remainingKey: "message.skipDetailRemaining"
        ) + limitedDetailMessages(
            for: unprocessedResults,
            line: unprocessedDetailMessage,
            remainingKey: "message.unprocessedDetailRemaining"
        )
    }

    private func limitedDetailMessages(
        for results: [FileOperationItemResult],
        line: (FileOperationItemResult) -> String,
        remainingKey: String
    ) -> [String] {
        guard !results.isEmpty else {
            return []
        }

        let shownResults: ArraySlice<FileOperationItemResult>
        let remainingCount: Int
        if fileOperationDetailLogLimit == 0 {
            shownResults = results[...]
            remainingCount = 0
        } else {
            shownResults = results.prefix(fileOperationDetailLogLimit)
            remainingCount = results.count - shownResults.count
        }

        var messages = shownResults.map(line)
        if remainingCount > 0 {
            messages.append(L10n.format(remainingKey, remainingCount))
        }
        return messages
    }

    private func operationSuccessDetailMessage(_ result: FileOperationItemResult, messageKey: String) -> String {
        if result.outcome == .trashed {
            return L10n.format(messageKey, result.sourceURL.lastPathComponent)
        }

        if let destinationURL = result.destinationURL {
            return L10n.format(messageKey, result.sourceURL.lastPathComponent, destinationURL.path)
        }

        return L10n.format(messageKey, result.sourceURL.lastPathComponent, "")
    }

    private func skipDetailMessage(_ result: FileOperationItemResult) -> String {
        let reason: String
        if case .skipped(let skipReason) = result.outcome {
            reason = localizedSkipReason(skipReason)
        } else {
            reason = localizedSkipReason(.conflict)
        }

        return L10n.format("message.skipDetail", result.sourceURL.lastPathComponent, reason)
    }

    private func unprocessedDetailMessage(_ result: FileOperationItemResult) -> String {
        L10n.format("message.unprocessedDetail", result.sourceURL.lastPathComponent)
    }

    private func localizedSkipReason(_ reason: FileOperationSkipReason) -> String {
        switch reason {
        case .conflict:
            return L10n.string("message.skipReason.conflict")
        case .sourceIsNotNewer:
            return L10n.string("message.skipReason.sourceIsNotNewer")
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else {
            return L10n.string("date.unknown")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter.string(from: date)
    }

    private func showDriveList() {
        do {
            let volumes = try driveListingService.locations()
            let controller = DriveListViewController(volumes: volumes, theme: displayThemeSet.selectedTheme)
            controller.preferredContentSize = DriveListViewController.preferredContentSize
            controller.onSelect = { [weak self] volume in
                self?.moveActivePane(to: volume)
            }
            controller.onCancel = { [weak self] in
                self?.closeDriveList()
            }

            driveListPanelController.present(
                contentViewController: controller,
                title: L10n.string("command.showDriveList"),
                theme: displayThemeSet.selectedTheme,
                relativeTo: view.window,
                onDismiss: { [weak self] in
                    self?.view.window?.makeFirstResponder(self)
                }
            )
            controller.focusList()
        } catch {
            appendMessage(L10n.format("message.driveListFailed", error.localizedDescription), in: activePane)
            render()
        }
    }

    private func closeDriveList() {
        driveListPanelController.dismiss()
    }

    private func showTagFilterList() {
        let tags = tagService.tags(in: activePaneState.items)
        guard !tags.isEmpty || activePaneState.tagFilterName != nil else {
            appendMessage(L10n.string("message.noTagsAvailable"), in: activePane)
            render()
            return
        }

        let controller = TagListViewController(
            mode: .filter(currentTagName: activePaneState.tagFilterName),
            tags: tags,
            theme: displayThemeSet.selectedTheme
        )
        controller.preferredContentSize = TagListViewController.preferredContentSize
        controller.onSelect = { [weak self] selection in
            self?.applyTagListSelection(selection)
        }
        controller.onCancel = { [weak self] in
            self?.closeTagList()
        }

        showTagListPanel(controller, title: L10n.string("tagList.filter.title"))
    }

    private func showTagEditList() {
        guard let selectedItem = activePaneState.selectedItem else {
            appendMessage(L10n.string("message.noTagEditTarget"), in: activePane)
            render()
            return
        }

        do {
            let selectedTags = try tagService.tags(of: selectedItem.url)
            let selectedTagNames = Set(selectedTags.map(\.name))
            let tags = tagService.tags(in: activePaneState.items)

            guard !tags.isEmpty else {
                appendMessage(L10n.string("message.noTagsAvailable"), in: activePane)
                render()
                return
            }

            let controller = TagListViewController(
                mode: .edit(assignedTagNames: selectedTagNames),
                tags: tags,
                theme: displayThemeSet.selectedTheme
            )
            controller.preferredContentSize = TagListViewController.preferredContentSize
            controller.onSelect = { [weak self] selection in
                self?.applyTagListSelection(selection)
            }
            controller.onCancel = { [weak self] in
                self?.closeTagList()
            }

            showTagListPanel(controller, title: L10n.string("tagList.edit.title"))
        } catch {
            appendMessage(L10n.format("message.tagListFailed", error.localizedDescription), in: activePane)
            render()
        }
    }

    private func showTagListPanel(_ controller: TagListViewController, title: String) {
        tagListPanelController.present(
            contentViewController: controller,
            title: title,
            theme: displayThemeSet.selectedTheme,
            relativeTo: view.window,
            onDismiss: { [weak self] in
                self?.view.window?.makeFirstResponder(self)
            }
        )
        controller.focusList()
    }

    private func closeTagList() {
        tagListPanelController.dismiss()
    }

    private func applyTagListSelection(_ selection: TagListSelection) {
        switch selection {
        case .clearFilter:
            mutateActivePane {
                $0.clearTagFilter()
                $0.loadCurrentDirectory(using: listingService)
            }
            appendMessage(L10n.string("message.tagFilterCleared"), in: activePane)
            closeTagList()
            render()
        case .filter(let tag):
            applyGlobalTagFilter(tag)
        case .toggle(let tag, let isAssigned):
            toggleTag(tag, isAssigned: isAssigned)
        }
    }

    private func applyGlobalTagFilter(_ tag: FileTag) {
        do {
            let items = try tagService.items(matching: tag)
            mutateActivePane { $0.applyTagSearchResults(items, tag: tag) }
            appendMessage(L10n.format("message.tagFilterApplied", tag.name), in: activePane)
            closeTagList()
            render()
        } catch {
            appendMessage(L10n.format("message.tagListFailed", error.localizedDescription), in: activePane)
            closeTagList()
            render()
        }
    }

    private func toggleTag(_ tag: FileTag, isAssigned: Bool) {
        guard let selectedItem = activePaneState.selectedItem else {
            appendMessage(L10n.string("message.noTagEditTarget"), in: activePane)
            closeTagList()
            render()
            return
        }

        let selectedURL = selectedItem.url
        let activeTagFilterName = activePaneState.tagFilterName
        let activeTagFilterColor = activePaneState.tagFilterColor
        do {
            try tagService.setTag(tag, enabled: !isAssigned, for: selectedURL)
            if let activeTagFilterName {
                let activeTag = FileTag(name: activeTagFilterName, color: activeTagFilterColor)
                let items = try tagService.items(matching: activeTag)
                mutateActivePane {
                    $0.applyTagSearchResults(items, tag: activeTag)
                    $0.selectItem(withURL: selectedURL)
                }
            } else {
                mutateActivePane {
                    $0.loadCurrentDirectory(using: listingService)
                    $0.selectItem(withURL: selectedURL)
                }
            }
            appendMessage(
                L10n.format(isAssigned ? "message.tagRemoved" : "message.tagAdded", tag.name, selectedItem.name),
                in: activePane
            )

            closeTagList()
            render()
        } catch {
            appendMessage(L10n.format("message.tagUpdateFailed", error.localizedDescription), in: activePane)
            render()
        }
    }

    private func moveActivePane(to entry: JumpPathEntry) {
        closeJumpPathList()

        let directory = URL(fileURLWithPath: entry.path, isDirectory: true)
        mutateActivePane { $0.moveToDirectory(directory, using: listingService) }
        appendMessage(pathChangedMessage(directory.path), in: activePane)
        postPaneDirectoriesDidChange()
        render()
    }

    private func movePaneToHistoryPath(
        _ destinationPane: ActivePane,
        at index: Int,
        usingHistoryFrom sourcePane: ActivePane
    ) {
        closeNavigationHistory()

        let sourceHistory = paneState(sourcePane).navigationHistory
        guard sourceHistory.paths.indices.contains(index) else {
            render()
            return
        }

        if sourcePane == destinationPane {
            let didMove = mutatePane(destinationPane) { $0.moveToHistoryPath(at: index, using: listingService) }
            if didMove {
                appendMessage(pathChangedMessage(paneState(destinationPane).currentDirectory.path), in: destinationPane)
                postPaneDirectoriesDidChange()
            }
            render()
            return
        }

        let directory = URL(fileURLWithPath: sourceHistory.paths[index], isDirectory: true)
        mutatePane(destinationPane) {
            $0.moveToDirectory(directory, using: listingService)
        }
        appendMessage(pathChangedMessage(paneState(destinationPane).currentDirectory.path), in: destinationPane)
        postPaneDirectoriesDidChange()
        render()
    }

    private func moveActivePaneBackwardInHistory() {
        let didMove = mutateActivePane { $0.moveBackwardInHistory(using: listingService) }
        if didMove {
            appendMessage(L10n.format("message.historyBack", activePaneState.currentDirectory.path), in: activePane)
            postPaneDirectoriesDidChange()
        }
        render()
    }

    private func moveActivePaneForwardInHistory() {
        let didMove = mutateActivePane { $0.moveForwardInHistory(using: listingService) }
        if didMove {
            appendMessage(L10n.format("message.historyForward", activePaneState.currentDirectory.path), in: activePane)
            postPaneDirectoriesDidChange()
        }
        render()
    }

    private func moveActivePane(to volume: DriveVolume) {
        closeDriveList()

        mutateActivePane { $0.moveToDirectory(volume.url, using: listingService) }
        appendMessage(L10n.format("message.locationChanged", volume.displayName), in: activePane)
        postPaneDirectoriesDidChange()
        render()
    }

    private func addCurrentPathToJumpList() {
        let currentPath = activePaneState.currentDirectory.path
        guard !jumpPathEntries.contains(where: { $0.normalizedPath == JumpPathEntry.normalizedPath(currentPath) }) else {
            return
        }

        jumpPathEntries.append(JumpPathEntry(displayName: "", path: currentPath))
        appendMessage(L10n.format("message.jumpPathAdded", currentPath), in: activePane)
        NotificationCenter.default.post(
            name: .jumpPathEntriesDidChange,
            object: self,
            userInfo: [SettingsNotificationKey.jumpPathEntries: jumpPathEntries]
        )

        if let controller = jumpPathPanelController.window?.contentViewController as? JumpPathListViewController {
            controller.updateEntries(jumpPathEntries, selectedIndex: jumpPathEntries.count - 1)
        }
    }

    private func adjustPaneDivider(by delta: Double) {
        leftState.adjustPaneWidthRatio(by: delta)
        rightState.setPaneWidthRatio(1.0 - leftState.paneWidthRatio)
        didApplyInitialPaneWidth = true
        applyPaneWidthRatio()
    }

    private func adjustMessageWindowDivider(by delta: Double) {
        leftState.adjustMessageWindowHeightRatio(by: delta)
        rightState.setMessageWindowHeightRatio(leftState.messageWindowHeightRatio)
        didApplyInitialMessageWindowHeight = true
        applyMessageWindowHeightRatio()
    }

    private func updatePaneWidthRatioFromSplitView() {
        guard !isApplyingPaneWidth else {
            return
        }

        let availableWidth = splitView.bounds.width - splitView.dividerThickness
        guard availableWidth > 0 else {
            return
        }

        guard didApplyInitialPaneWidth else {
            applyPaneWidthRatio()
            return
        }

        leftState.setPaneWidthRatio(leftPaneView.frame.width / availableWidth)
        rightState.setPaneWidthRatio(1.0 - leftState.paneWidthRatio)
    }

    private func updateMessageWindowHeightRatioFromSplitView() {
        guard !isApplyingMessageWindowHeight else {
            return
        }

        let availableHeight = rootSplitView.bounds.height - rootSplitView.dividerThickness
        guard availableHeight > 0 else {
            return
        }

        guard didApplyInitialMessageWindowHeight else {
            applyMessageWindowHeightRatio()
            return
        }

        leftState.setMessageWindowHeightRatio(messageLogView.frame.height / availableHeight)
        rightState.setMessageWindowHeightRatio(leftState.messageWindowHeightRatio)
    }

    private func applyPaneWidthRatio() {
        let availableWidth = splitView.bounds.width - splitView.dividerThickness
        guard availableWidth > 0 else {
            return
        }

        isApplyingPaneWidth = true
        splitView.setPosition(availableWidth * leftState.paneWidthRatio, ofDividerAt: 0)
        isApplyingPaneWidth = false
        didApplyInitialPaneWidth = true
    }

    private func applyMessageWindowHeightRatio() {
        let availableHeight = rootSplitView.bounds.height - rootSplitView.dividerThickness
        guard availableHeight > 0 else {
            return
        }

        isApplyingMessageWindowHeight = true
        rootSplitView.setPosition(availableHeight * (1.0 - leftState.messageWindowHeightRatio), ofDividerAt: 0)
        isApplyingMessageWindowHeight = false
        didApplyInitialMessageWindowHeight = true
    }

    private func appendMessage(_ message: String, in pane: ActivePane) {
        appendMessageLine("\(pane.messagePrefix): \(message)")
    }

    private func appendMessages(_ messages: [String], in pane: ActivePane) {
        for message in messages {
            appendMessage(message, in: pane)
        }
    }

    private func pathChangedMessage(_ path: String) -> String {
        L10n.format("message.pathChanged", path)
    }

    private func localizedOnOff(_ value: Bool) -> String {
        L10n.string(value ? "common.on" : "common.off")
    }

    private func appendMessageToBothPanes(_ message: String) {
        appendMessage(message, in: .left)
        appendMessage(message, in: .right)
    }

    private func appendMessageLine(_ message: String) {
        leftState.appendMessage(message)
        rightState.appendMessage(message)
    }

    private func postPaneDirectoriesDidChange() {
        NotificationCenter.default.post(
            name: .paneDirectoriesDidChange,
            object: self,
            userInfo: [
                SettingsNotificationKey.leftPanePath: leftState.currentDirectory.path,
                SettingsNotificationKey.rightPanePath: rightState.currentDirectory.path,
                SettingsNotificationKey.leftPaneNavigationHistory: leftState.navigationHistory,
                SettingsNotificationKey.rightPaneNavigationHistory: rightState.navigationHistory,
                SettingsNotificationKey.leftPaneSortDescriptor: leftState.sortDescriptor,
                SettingsNotificationKey.rightPaneSortDescriptor: rightState.sortDescriptor
            ]
        )
    }

    private func mutateActivePane(_ update: (inout PaneState) -> Void) {
        mutatePane(activePane, update)
    }

    private func mutateActivePane<Result>(_ update: (inout PaneState) -> Result) -> Result {
        mutatePane(activePane, update)
    }

    private func mutatePane(_ pane: ActivePane, _ update: (inout PaneState) -> Void) {
        switch pane {
        case .left:
            update(&leftState)
        case .right:
            update(&rightState)
        }
    }

    private func mutatePane<Result>(_ pane: ActivePane, _ update: (inout PaneState) -> Result) -> Result {
        switch pane {
        case .left:
            return update(&leftState)
        case .right:
            return update(&rightState)
        }
    }

    private var activePaneState: PaneState {
        paneState(activePane)
    }

    private var activePaneView: FilePaneView {
        switch activePane {
        case .left:
            return leftPaneView
        case .right:
            return rightPaneView
        }
    }

    private func paneState(_ pane: ActivePane) -> PaneState {
        switch pane {
        case .left:
            return leftState
        case .right:
            return rightState
        }
    }

    private func render(preservingScrollPositionIn pane: ActivePane? = nil) {
        applyWindowTheme()
        leftPaneView.render(
            state: leftState,
            isActive: activePane == .left,
            title: L10n.string("pane.left"),
            pendingKeySequenceDisplayText: activePane == .left ? pendingKeySequence?.displayText : nil,
            usesAlternatingRowBackgrounds: usesAlternatingRowBackgrounds,
            showsFileIcons: showsFileIcons,
            showsFileTagColors: showsFileTagColors,
            showsFileExtensionsSeparately: showsFileExtensionsSeparately,
            fileTypeAssociations: fileTypeAssociations,
            fileTypeColorScope: fileTypeColorScope,
            theme: displayThemeSet.selectedTheme,
            preservesScrollPosition: pane == .left
        )
        rightPaneView.render(
            state: rightState,
            isActive: activePane == .right,
            title: L10n.string("pane.right"),
            pendingKeySequenceDisplayText: activePane == .right ? pendingKeySequence?.displayText : nil,
            usesAlternatingRowBackgrounds: usesAlternatingRowBackgrounds,
            showsFileIcons: showsFileIcons,
            showsFileTagColors: showsFileTagColors,
            showsFileExtensionsSeparately: showsFileExtensionsSeparately,
            fileTypeAssociations: fileTypeAssociations,
            fileTypeColorScope: fileTypeColorScope,
            theme: displayThemeSet.selectedTheme,
            preservesScrollPosition: pane == .right
        )
        messageLogView.render(messages: leftState.messageLines, theme: displayThemeSet.selectedTheme)
        applyPaneWidthRatio()
        applyMessageWindowHeightRatio()
    }

    private func applyWindowTheme() {
        let backgroundColor = themedBackgroundColor
        view.layer?.backgroundColor = backgroundColor.cgColor
        let usesContentTransparency = displayThemeSet.selectedTheme.usesContentTransparency
        view.window?.isOpaque = !usesContentTransparency
        view.window?.titlebarAppearsTransparent = !usesContentTransparency
        view.window?.backgroundColor = backgroundColor
    }

    func splitViewDidResizeSubviews(_ notification: Notification) {
        guard let resizedSplitView = notification.object as? NSSplitView else {
            return
        }

        if resizedSplitView === splitView {
            updatePaneWidthRatioFromSplitView()
        } else if resizedSplitView === rootSplitView {
            updateMessageWindowHeightRatioFromSplitView()
            applyPaneWidthRatio()
        }
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMinCoordinate proposedMinimumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if splitView === rootSplitView {
            return splitView.bounds.height * 0.55
        }

        return splitView.bounds.width * 0.2
    }

    func splitView(
        _ splitView: NSSplitView,
        constrainMaxCoordinate proposedMaximumPosition: CGFloat,
        ofSubviewAt dividerIndex: Int
    ) -> CGFloat {
        if splitView === rootSplitView {
            return splitView.bounds.height * 0.88
        }

        return splitView.bounds.width * 0.8
    }

    private func refreshVisibleFloatingListPanels() {
        guard jumpPathPanelController.window?.isVisible == true
                || navigationHistoryPanelController.window?.isVisible == true
                || driveListPanelController.window?.isVisible == true
                || tagListPanelController.window?.isVisible == true
                || sameNamedFileMarkPanelController.window?.isVisible == true else {
            return
        }

        // テーマ変更時は内容ビューを作り直し、ウィンドウ位置は維持する。
        if jumpPathPanelController.window?.isVisible == true {
            showJumpPathList()
        }
        if navigationHistoryPanelController.window?.isVisible == true {
            showNavigationHistory()
        }
        if driveListPanelController.window?.isVisible == true {
            showDriveList()
        }
        if let controller = tagListPanelController.window?.contentViewController as? TagListViewController {
            switch controller.currentMode {
            case .filter:
                showTagFilterList()
            case .edit:
                showTagEditList()
            }
        }
        if sameNamedFileMarkPanelController.window?.isVisible == true {
            showSameNamedFileMarkOptions()
        }
    }

    @objc private func mainWindowDidBecomeKey(_ notification: Notification) {
        guard let mainWindow = notification.object as? NSWindow,
              mainWindow === view.window else {
            return
        }

        // メイン画面へ戻った時点で、補助パネル内の一覧操作を終了する。
        jumpPathPanelController.dismiss()
        navigationHistoryPanelController.dismiss()
        driveListPanelController.dismiss()
        tagListPanelController.dismiss()
        sameNamedFileMarkPanelController.dismiss()
    }
}

private final class SameNamedFileMarkOptionsViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 340, height: 150)

    var onApply: ((SameNamedFileMarkOptions) -> Void)?
    var onCancel: (() -> Void)?

    private let theme: DisplayTheme
    private let optionsView: SameNamedFileMarkOptionsView

    init(theme: DisplayTheme) {
        self.theme = theme
        self.optionsView = SameNamedFileMarkOptionsView(theme: theme)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        container.wantsLayer = true
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = baseColors.background?.nsColor ?? .windowBackgroundColor
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor
        container.layer?.backgroundColor = backgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: L10n.string("sameNamedFile.title"))
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = foregroundColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        optionsView.translatesAutoresizingMaskIntoConstraints = false
        optionsView.onApply = { [weak self] options in
            self?.onApply?(options)
        }
        optionsView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        container.addSubview(titleLabel)
        container.addSubview(optionsView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            optionsView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            optionsView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            optionsView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            optionsView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        view = container
    }

    func focusOptions() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.view.window?.makeFirstResponder(self.optionsView)
        }
    }
}

private final class SameNamedFileMarkOptionsView: NSView {
    var onApply: ((SameNamedFileMarkOptions) -> Void)?
    var onCancel: (() -> Void)?

    private let sizeCheckbox = NSButton(checkboxWithTitle: L10n.string("sameNamedFile.compareSize"), target: nil, action: nil)
    private let dateCheckbox = NSButton(checkboxWithTitle: L10n.string("sameNamedFile.compareModifiedDate"), target: nil, action: nil)
    private let applyButton = NSButton(title: L10n.string("sameNamedFile.mark"), target: nil, action: nil)
    private let controls: [NSControl]
    private var focusedControlIndex = 0
    private let theme: DisplayTheme

    override var acceptsFirstResponder: Bool {
        true
    }

    init(theme: DisplayTheme) {
        self.theme = theme
        controls = [sizeCheckbox, dateCheckbox, applyButton]
        super.init(frame: .zero)
        buildView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func becomeFirstResponder() -> Bool {
        renderFocus()
        return true
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.upArrow, AppKeyCode.leftArrow:
            moveFocus(by: -1)
        case AppKeyCode.downArrow, AppKeyCode.rightArrow:
            moveFocus(by: 1)
        case AppKeyCode.space:
            activateFocusedControl()
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            apply()
        case AppKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }

    private func buildView() {
        applyButton.target = self
        applyButton.action = #selector(applyClicked(_:))
        applyButton.bezelStyle = .rounded

        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: foregroundColor,
            .paragraphStyle: paragraphStyle,
            .font: NSFont.systemFont(ofSize: 13)
        ]

        sizeCheckbox.attributedTitle = NSAttributedString(string: L10n.string("sameNamedFile.compareSize"), attributes: attributes)
        dateCheckbox.attributedTitle = NSAttributedString(string: L10n.string("sameNamedFile.compareModifiedDate"), attributes: attributes)

        let stack = NSStackView(views: [sizeCheckbox, dateCheckbox, applyButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])

        renderFocus()
    }

    @objc private func applyClicked(_ sender: NSButton) {
        apply()
    }

    private func moveFocus(by delta: Int) {
        focusedControlIndex = max(0, min(controls.count - 1, focusedControlIndex + delta))
        renderFocus()
    }

    private func activateFocusedControl() {
        let control = controls[focusedControlIndex]
        if control !== applyButton, let checkbox = control as? NSButton {
            checkbox.state = checkbox.state == .on ? .off : .on
        } else {
            apply()
        }
        renderFocus()
    }

    private func renderFocus() {
        let baseColors = theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false)
        let focusColor = theme.resolvedFocusColorPair.background?.nsColor ?? baseColors.background?.nsColor ?? NSColor.controlAccentColor
        for (index, control) in controls.enumerated() {
            control.wantsLayer = true
            control.layer?.borderWidth = index == focusedControlIndex ? 2 : 0
            control.layer?.borderColor = focusColor.cgColor
        }
    }

    private func apply() {
        onApply?(SameNamedFileMarkOptions(
            comparesByteSize: sizeCheckbox.state == .on,
            comparesModificationDate: dateCheckbox.state == .on
        ))
    }
}

private enum TagListMode: Equatable {
    case filter(currentTagName: String?)
    case edit(assignedTagNames: Set<String>)
}

private enum TagListSelection {
    case clearFilter
    case filter(FileTag)
    case toggle(FileTag, isAssigned: Bool)
}

private struct TagListEntry: Equatable {
    enum Kind: Equatable {
        case clearFilter
        case tag(FileTag)
    }

    let kind: Kind
    let title: String
    let isAssigned: Bool
    let isCurrentFilter: Bool
    let showsAssignmentState: Bool
    let color: FileTagColor?
}

private final class TagListViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 360, height: 260)

    var onSelect: ((TagListSelection) -> Void)?
    var onCancel: (() -> Void)?

    private var mode: TagListMode
    private let tags: [FileTag]
    private let theme: DisplayTheme
    private let tableView = TagListTableView()
    private let scrollView = NSScrollView()
    private let dataSource = TagListDataSource()

    var currentMode: TagListMode {
        mode
    }

    init(mode: TagListMode, tags: [FileTag], theme: DisplayTheme) {
        self.mode = mode
        self.tags = tags
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        container.wantsLayer = true
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = baseColors.background?.nsColor ?? .windowBackgroundColor
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor
        container.layer?.backgroundColor = backgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: listTitle)
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = foregroundColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dataSource.theme = theme
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = entries.isEmpty
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = backgroundColor
        tableView.target = self
        tableView.action = #selector(tableClicked(_:))
        tableView.onMoveSelection = { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        tableView.onOpenSelection = { [weak self] in
            self?.openSelectedEntry()
        }
        tableView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        let markerColumn = NSTableColumn(identifier: TagListDataSource.markerColumnIdentifier)
        markerColumn.title = ""
        markerColumn.width = 24
        markerColumn.minWidth = 24
        markerColumn.maxWidth = 24
        markerColumn.resizingMask = []
        tableView.addTableColumn(markerColumn)

        let nameColumn = NSTableColumn(identifier: TagListDataSource.nameColumnIdentifier)
        nameColumn.title = "Tag"
        nameColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(nameColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render(selectedIndex: entries.isEmpty ? nil : 0)
    }

    func focusList() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.view.window?.makeFirstResponder(self.tableView)
        }
    }

    func updateMode(_ mode: TagListMode) {
        self.mode = mode
        render(selectedIndex: tableView.selectedRow >= 0 ? tableView.selectedRow : 0)
    }

    @objc private func tableClicked(_ sender: NSTableView) {
        openSelectedEntry()
    }

    private var listTitle: String {
        switch mode {
        case .filter:
            return L10n.string("tagList.filter.title")
        case .edit:
            return L10n.string("tagList.edit.title")
        }
    }

    private var entries: [TagListEntry] {
        switch mode {
        case .filter(let currentTagName):
            let clearEntry = TagListEntry(
                kind: .clearFilter,
                title: L10n.string("tagList.allTags"),
                isAssigned: false,
                isCurrentFilter: currentTagName == nil,
                showsAssignmentState: false,
                color: nil
            )
            let tagEntries = tags.map { tag in
                TagListEntry(
                    kind: .tag(tag),
                    title: tag.name,
                    isAssigned: false,
                    isCurrentFilter: tag.name == currentTagName,
                    showsAssignmentState: false,
                    color: tag.color
                )
            }
            return [clearEntry] + tagEntries
        case .edit(let assignedTagNames):
            return tags.map { tag in
                TagListEntry(
                    kind: .tag(tag),
                    title: tag.name,
                    isAssigned: assignedTagNames.contains(tag.name),
                    isCurrentFilter: false,
                    showsAssignmentState: true,
                    color: tag.color
                )
            }
        }
    }

    private func moveSelection(by delta: Int) {
        let entries = entries
        guard !entries.isEmpty else {
            return
        }

        let previousRow = tableView.selectedRow
        let selectedRow = previousRow >= 0 ? previousRow : 0
        let nextRow = max(0, min(entries.count - 1, selectedRow + delta))
        dataSource.selectedRow = nextRow
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        refreshRows(previousRow, nextRow)
    }

    private func openSelectedEntry() {
        let row = tableView.selectedRow
        let entries = entries
        guard entries.indices.contains(row) else {
            return
        }

        let entry = entries[row]
        switch (mode, entry.kind) {
        case (.filter, .clearFilter):
            onSelect?(.clearFilter)
        case (.filter, .tag(let tag)):
            onSelect?(.filter(tag))
        case (.edit, .tag(let tag)):
            onSelect?(.toggle(tag, isAssigned: entry.isAssigned))
        case (.edit, .clearFilter):
            break
        }
    }

    private func render(selectedIndex: Int?) {
        let entries = entries
        dataSource.entries = entries
        tableView.reloadData()

        guard let selectedIndex, entries.indices.contains(selectedIndex) else {
            dataSource.selectedRow = nil
            tableView.deselectAll(nil)
            return
        }

        dataSource.selectedRow = selectedIndex
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
        refreshRows(selectedIndex)
    }

    private func refreshRows(_ rows: Int...) {
        let entries = entries
        let validRows = rows.filter { entries.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = dataSource.backgroundColor(row: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }
}

private final class TagListTableView: NSTableView {
    var onMoveSelection: ((Int) -> Void)?
    var onOpenSelection: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.upArrow:
            onMoveSelection?(-1)
        case AppKeyCode.downArrow:
            onMoveSelection?(1)
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            onOpenSelection?()
        case AppKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class TagListDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let markerColumnIdentifier = NSUserInterfaceItemIdentifier("tagMarker")
    static let nameColumnIdentifier = NSUserInterfaceItemIdentifier("tagName")

    var entries: [TagListEntry] = []
    var theme: DisplayTheme = .light
    var selectedRow: Int?

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row) else {
            return nil
        }

        let isMarkerColumn = tableColumn?.identifier == Self.markerColumnIdentifier
        let identifier = isMarkerColumn
            ? NSUserInterfaceItemIdentifier("tagMarkerCell")
            : NSUserInterfaceItemIdentifier("tagNameCell")
        let entry = entries[row]
        let cell: NSTableCellView
        if isMarkerColumn {
            cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        } else {
            cell = tableView.makeView(withIdentifier: identifier, owner: self) as? TagNameCellView ?? TagNameCellView()
        }
        cell.identifier = identifier

        let textField = cell.textField ?? NSTextField(labelWithString: "")
        textField.stringValue = isMarkerColumn ? markerText(for: entry) : entry.title
        textField.font = isMarkerColumn ? .monospacedSystemFont(ofSize: 13, weight: .regular) : .systemFont(ofSize: 13)
        textField.textColor = textColor(row: row)
        textField.lineBreakMode = .byTruncatingTail
        textField.alignment = isMarkerColumn ? .center : .left
        textField.translatesAutoresizingMaskIntoConstraints = false

        if textField.superview == nil {
            cell.addSubview(textField)
            cell.textField = textField
            cell.identifier = identifier

            let leadingConstant: CGFloat = isMarkerColumn ? 8 : 24
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: leadingConstant),
                textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -8),
                textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }

        if let nameCell = cell as? TagNameCellView {
            nameCell.tagColor = entry.color?.nsColor
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard entries.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("tagRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? ThemedListRowView ?? ThemedListRowView()
        rowView.identifier = identifier
        rowView.rowBackgroundColor = backgroundColor(row: row)
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        let previousRow = selectedRow
        let newRow = entries.indices.contains(tableView.selectedRow) ? tableView.selectedRow : nil
        selectedRow = newRow
        refreshRows(tableView: tableView, rows: [previousRow, newRow].compactMap { $0 })
    }

    func backgroundColor(row: Int) -> NSColor {
        guard selectedRow == row else {
            return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).background?.nsColor
                ?? .textBackgroundColor
        }

        return theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).background?.nsColor
            ?? .selectedContentBackgroundColor
    }

    private func textColor(row: Int) -> NSColor {
        if selectedRow == row {
            return theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).foreground?.nsColor
                ?? .selectedTextColor
        }

        return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).foreground?.nsColor
            ?? .labelColor
    }

    private func markerText(for entry: TagListEntry) -> String {
        if entry.isAssigned {
            return "*"
        }

        if entry.isCurrentFilter {
            return ">"
        }

        return ""
    }

    private func refreshRows(tableView: NSTableView, rows: [Int]) {
        let validRows = rows.filter { entries.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = backgroundColor(row: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }
}

private final class TagNameCellView: NSTableCellView {
    var tagColor: NSColor? {
        didSet {
            colorMarkerView.markerColor = tagColor
        }
    }

    private let colorMarkerView = TagColorMarkerView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setup() {
        colorMarkerView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(colorMarkerView)

        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        self.textField = textField

        NSLayoutConstraint.activate([
            colorMarkerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            colorMarkerView.centerYAnchor.constraint(equalTo: centerYAnchor),
            colorMarkerView.widthAnchor.constraint(equalToConstant: 10),
            colorMarkerView.heightAnchor.constraint(equalToConstant: 10),

            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
}

private final class TagColorMarkerView: NSView {
    var markerColor: NSColor? {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let markerColor else {
            NSColor.separatorColor.setStroke()
            NSBezierPath(ovalIn: bounds.insetBy(dx: 2.5, dy: 2.5)).stroke()
            return
        }

        markerColor.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}

private final class DriveListViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 420, height: 260)

    var onSelect: ((DriveVolume) -> Void)?
    var onCancel: (() -> Void)?

    private var volumes: [DriveVolume]
    private let theme: DisplayTheme
    private let tableView = DriveListTableView()
    private let scrollView = NSScrollView()
    private let dataSource = DriveListDataSource()

    init(volumes: [DriveVolume], theme: DisplayTheme) {
        self.volumes = volumes
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        container.wantsLayer = true
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = baseColors.background?.nsColor ?? .windowBackgroundColor
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor
        container.layer?.backgroundColor = backgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "Locations")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = foregroundColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dataSource.theme = theme
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = volumes.isEmpty
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = backgroundColor
        tableView.target = self
        tableView.action = #selector(tableClicked(_:))
        tableView.onMoveSelection = { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        tableView.onOpenSelection = { [weak self] in
            self?.openSelectedVolume()
        }
        tableView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        let nameColumn = NSTableColumn(identifier: DriveListDataSource.nameColumnIdentifier)
        nameColumn.title = "Name"
        nameColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(nameColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render(selectedIndex: volumes.isEmpty ? nil : 0)
    }

    func focusList() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.view.window?.makeFirstResponder(self.tableView)
        }
    }

    @objc private func tableClicked(_ sender: NSTableView) {
        openSelectedVolume()
    }

    private func moveSelection(by delta: Int) {
        guard !volumes.isEmpty else {
            return
        }

        let previousRow = tableView.selectedRow
        let selectedRow = previousRow >= 0 ? previousRow : 0
        let nextRow = max(0, min(volumes.count - 1, selectedRow + delta))
        dataSource.selectedRow = nextRow
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        refreshRows(previousRow, nextRow)
    }

    private func openSelectedVolume() {
        let row = tableView.selectedRow
        guard volumes.indices.contains(row) else {
            return
        }

        onSelect?(volumes[row])
    }

    private func render(selectedIndex: Int?) {
        dataSource.volumes = volumes
        tableView.reloadData()

        guard let selectedIndex, volumes.indices.contains(selectedIndex) else {
            tableView.deselectAll(nil)
            return
        }

        dataSource.selectedRow = selectedIndex
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
        refreshRows(selectedIndex)
    }

    private func refreshRows(_ rows: Int...) {
        let validRows = rows.filter { volumes.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = dataSource.backgroundColor(tableView: tableView, row: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }
}

private final class DriveListTableView: NSTableView {
    var onMoveSelection: ((Int) -> Void)?
    var onOpenSelection: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.upArrow:
            onMoveSelection?(-1)
        case AppKeyCode.downArrow:
            onMoveSelection?(1)
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            onOpenSelection?()
        case AppKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class DriveListDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let nameColumnIdentifier = NSUserInterfaceItemIdentifier("driveName")

    var volumes: [DriveVolume] = []
    var theme: DisplayTheme = .light
    var selectedRow: Int?

    func numberOfRows(in tableView: NSTableView) -> Int {
        volumes.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard volumes.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("driveCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        let volume = volumes[row]

        textField.stringValue = "\(volume.displayName)  —  \(volume.url.path)"
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = textColor(tableView: tableView, row: row)
        textField.lineBreakMode = .byTruncatingMiddle
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

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard volumes.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("driveRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? ThemedListRowView ?? ThemedListRowView()
        rowView.identifier = identifier
        rowView.rowBackgroundColor = backgroundColor(tableView: tableView, row: row)
        return rowView
    }

    func backgroundColor(tableView: NSTableView, row: Int) -> NSColor {
        guard selectedRow == row else {
            return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).background?.nsColor
                ?? .textBackgroundColor
        }

        return selectedBackgroundColor
    }

    private func textColor(tableView: NSTableView, row: Int) -> NSColor {
        if selectedRow == row {
            return theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).foreground?.nsColor
                ?? .selectedTextColor
        }

        return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).foreground?.nsColor
            ?? .labelColor
    }

    private var selectedBackgroundColor: NSColor {
        theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).background?.nsColor
            ?? .selectedContentBackgroundColor
    }
}

private final class JumpPathListViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 420, height: 260)

    var onSelect: ((JumpPathEntry) -> Void)?
    var onAddCurrentPath: (() -> Void)?
    var onCancel: (() -> Void)?

    private var entries: [JumpPathEntry]
    private let theme: DisplayTheme
    private let tableView = JumpPathTableView()
    private let scrollView = NSScrollView()
    private let dataSource = JumpPathDataSource()

    init(entries: [JumpPathEntry], theme: DisplayTheme) {
        self.entries = entries
        self.theme = theme
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        container.wantsLayer = true
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = baseColors.background?.nsColor ?? .windowBackgroundColor
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor
        container.layer?.backgroundColor = backgroundColor.cgColor

        let titleLabel = NSTextField(labelWithString: "Jump Paths")
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = foregroundColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let hintLabel = NSTextField(labelWithString: "+: add current path")
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = foregroundColor
        hintLabel.backgroundColor = backgroundColor
        hintLabel.translatesAutoresizingMaskIntoConstraints = false

        dataSource.theme = theme
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = entries.isEmpty
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = backgroundColor
        tableView.target = self
        tableView.action = #selector(tableClicked(_:))
        tableView.onMoveSelection = { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        tableView.onOpenSelection = { [weak self] in
            self?.openSelectedEntry()
        }
        tableView.onAddCurrentPath = { [weak self] in
            self?.onAddCurrentPath?()
        }
        tableView.onSelectQuickEntry = { [weak self] index in
            self?.openEntry(at: index)
        }
        tableView.onCancel = { [weak self] in
            self?.onCancel?()
        }

        let shortcutColumn = NSTableColumn(identifier: JumpPathDataSource.shortcutColumnIdentifier)
        shortcutColumn.width = 36
        shortcutColumn.minWidth = 36
        shortcutColumn.maxWidth = 36
        shortcutColumn.resizingMask = []
        tableView.addTableColumn(shortcutColumn)

        let nameColumn = NSTableColumn(identifier: JumpPathDataSource.nameColumnIdentifier)
        nameColumn.width = 130
        nameColumn.minWidth = 80
        nameColumn.resizingMask = .userResizingMask
        tableView.addTableColumn(nameColumn)

        let pathColumn = NSTableColumn(identifier: JumpPathDataSource.pathColumnIdentifier)
        pathColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(pathColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(hintLabel)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            hintLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            hintLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render(selectedIndex: entries.isEmpty ? nil : 0)
    }

    func focusList() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.view.window?.makeFirstResponder(self.tableView)
        }
    }

    func updateEntries(_ entries: [JumpPathEntry], selectedIndex: Int?) {
        self.entries = entries
        render(selectedIndex: selectedIndex)
    }

    @objc private func tableClicked(_ sender: NSTableView) {
        openSelectedEntry()
    }

    private func moveSelection(by delta: Int) {
        guard !entries.isEmpty else {
            return
        }

        let previousRow = tableView.selectedRow
        let selectedRow = previousRow >= 0 ? previousRow : 0
        let nextRow = max(0, min(entries.count - 1, selectedRow + delta))
        dataSource.selectedRow = nextRow
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
        refreshRows(previousRow, nextRow)
    }

    private func openSelectedEntry() {
        openEntry(at: tableView.selectedRow)
    }

    private func openEntry(at index: Int) {
        guard entries.indices.contains(index) else {
            return
        }

        onSelect?(entries[index])
    }

    private func render(selectedIndex: Int?) {
        dataSource.entries = entries
        tableView.reloadData()

        guard let selectedIndex, entries.indices.contains(selectedIndex) else {
            dataSource.selectedRow = nil
            tableView.deselectAll(nil)
            return
        }

        dataSource.selectedRow = selectedIndex
        tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(selectedIndex)
        refreshRows(selectedIndex)
    }

    private func refreshRows(_ rows: Int...) {
        let validRows = rows.filter { entries.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = dataSource.backgroundColor(tableView: tableView, row: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }
}

private final class JumpPathTableView: NSTableView {
    var onMoveSelection: ((Int) -> Void)?
    var onOpenSelection: (() -> Void)?
    var onAddCurrentPath: (() -> Void)?
    var onSelectQuickEntry: ((Int) -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.upArrow:
            onMoveSelection?(-1)
        case AppKeyCode.downArrow:
            onMoveSelection?(1)
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            onOpenSelection?()
        case AppKeyCode.escape:
            onCancel?()
        default:
            if let quickEntryIndex = quickEntryIndex(for: event) {
                onSelectQuickEntry?(quickEntryIndex)
            } else if event.charactersIgnoringModifiers == "+" || event.characters == "+" {
                onAddCurrentPath?()
            } else {
                super.keyDown(with: event)
            }
        }
    }

    private func quickEntryIndex(for event: NSEvent) -> Int? {
        let shortcutModifiers: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        guard event.modifierFlags.intersection(shortcutModifiers).isEmpty else {
            return nil
        }

        switch event.charactersIgnoringModifiers {
        case "1": return 0
        case "2": return 1
        case "3": return 2
        case "4": return 3
        case "5": return 4
        case "6": return 5
        case "7": return 6
        case "8": return 7
        case "9": return 8
        case "0": return 9
        default: return nil
        }
    }
}

private final class JumpPathDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let shortcutColumnIdentifier = NSUserInterfaceItemIdentifier("jumpPathShortcut")
    static let nameColumnIdentifier = NSUserInterfaceItemIdentifier("jumpPathName")
    static let pathColumnIdentifier = NSUserInterfaceItemIdentifier("jumpPathPath")

    var entries: [JumpPathEntry] = []
    var theme: DisplayTheme = .light
    var selectedRow: Int?

    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard entries.indices.contains(row), let tableColumn else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("jumpPathCell.\(tableColumn.identifier.rawValue)")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")
        let entry = entries[row]

        switch tableColumn.identifier {
        case Self.shortcutColumnIdentifier:
            textField.stringValue = quickShortcutTitle(for: row)
            textField.alignment = .center
            textField.lineBreakMode = .byClipping
        case Self.nameColumnIdentifier:
            textField.stringValue = entry.displayName
            textField.alignment = .left
            textField.lineBreakMode = .byTruncatingTail
        case Self.pathColumnIdentifier:
            textField.stringValue = entry.path
            textField.alignment = .left
            textField.lineBreakMode = .byTruncatingMiddle
        default:
            return nil
        }
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = textColor(tableView: tableView, row: row)
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

    private func quickShortcutTitle(for row: Int) -> String {
        guard row < 10 else {
            return ""
        }

        return row == 9 ? "0" : String(row + 1)
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard entries.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("jumpPathRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? ThemedListRowView ?? ThemedListRowView()
        rowView.identifier = identifier
        rowView.rowBackgroundColor = backgroundColor(tableView: tableView, row: row)
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        let previousRow = selectedRow
        let newRow = entries.indices.contains(tableView.selectedRow) ? tableView.selectedRow : nil
        selectedRow = newRow

        refreshRows(tableView: tableView, rows: [previousRow, newRow].compactMap { $0 })
    }

    func backgroundColor(tableView: NSTableView, row: Int) -> NSColor {
        guard selectedRow == row else {
            return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).background?.nsColor
                ?? .textBackgroundColor
        }

        return selectedBackgroundColor
    }

    private func textColor(tableView: NSTableView, row: Int) -> NSColor {
        if selectedRow == row {
            return theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).foreground?.nsColor
                ?? .selectedTextColor
        }

        return theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false).foreground?.nsColor
            ?? .labelColor
    }

    private var selectedBackgroundColor: NSColor {
        theme.resolvedColorPair(isSelected: true, isMarked: false, isDirectory: false).background?.nsColor
            ?? .selectedContentBackgroundColor
    }

    private func refreshRows(tableView: NSTableView, rows: [Int]) {
        let validRows = rows.filter { entries.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = backgroundColor(tableView: tableView, row: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }
}

private final class NavigationHistoryViewController: NSViewController {
    static let preferredContentSize = NSSize(width: 460, height: 280)

    var onSelect: ((ActivePane, Int, Bool) -> Void)?
    var onCancel: (() -> Void)?

    private let historyProvider: (ActivePane) -> NavigationHistory
    private let theme: DisplayTheme
    private var displayedPane: ActivePane
    private var displayedHistory: NavigationHistory {
        historyProvider(displayedPane)
    }
    private var paths: [String] {
        displayedHistory.paths
    }
    private let titleLabel = NSTextField(labelWithString: "")
    private let tableView = NavigationHistoryTableView()
    private let scrollView = NSScrollView()
    private let dataSource = NavigationHistoryDataSource()

    init(
        initialPane: ActivePane,
        theme: DisplayTheme,
        historyProvider: @escaping (ActivePane) -> NavigationHistory
    ) {
        displayedPane = initialPane
        self.theme = theme
        self.historyProvider = historyProvider
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView(frame: NSRect(origin: .zero, size: Self.preferredContentSize))
        container.wantsLayer = true
        let colors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = colors.background?.nsColor ?? .windowBackgroundColor
        let foregroundColor = colors.foreground?.nsColor ?? .labelColor
        container.layer?.backgroundColor = backgroundColor.cgColor

        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.textColor = foregroundColor
        titleLabel.backgroundColor = backgroundColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dataSource.theme = theme
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = paths.isEmpty
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.target = self
        tableView.action = #selector(tableClicked(_:))
        tableView.onMoveSelection = { [weak self] delta in
            self?.moveSelection(by: delta)
        }
        tableView.onOpenSelection = { [weak self] opensInOppositePane in
            self?.openSelectedPath(opensInOppositePane: opensInOppositePane)
        }
        tableView.onSwitchPane = { [weak self] pane in
            self?.switchDisplayedPane(to: pane)
        }
        tableView.onCancel = { [weak self] in
            self?.onCancel?()
        }
        tableView.backgroundColor = backgroundColor

        let pathColumn = NSTableColumn(identifier: NavigationHistoryDataSource.pathColumnIdentifier)
        pathColumn.title = "Path"
        pathColumn.resizingMask = .autoresizingMask
        tableView.addTableColumn(pathColumn)

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),

            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        render()
    }

    func focusList() {
        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            self.view.window?.makeFirstResponder(self.tableView)
        }
    }

    @objc private func tableClicked(_ sender: NSTableView) {
        openSelectedPath(opensInOppositePane: false)
    }

    private func moveSelection(by delta: Int) {
        guard !paths.isEmpty else {
            return
        }

        let selectedRow = tableView.selectedRow >= 0 ? tableView.selectedRow : 0
        let nextRow = max(0, min(paths.count - 1, selectedRow + delta))
        tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
        tableView.scrollRowToVisible(nextRow)
    }

    private func switchDisplayedPane(to pane: ActivePane) {
        guard displayedPane != pane else {
            return
        }

        displayedPane = pane
        render()
    }

    private func openSelectedPath(opensInOppositePane: Bool) {
        let row = tableView.selectedRow
        guard paths.indices.contains(row) else {
            return
        }

        onSelect?(displayedPane, row, opensInOppositePane)
    }

    private func render() {
        let history = displayedHistory
        titleLabel.stringValue = displayedPane == .left ? "Left History" : "Right History"
        dataSource.paths = paths
        tableView.reloadData()

        guard paths.indices.contains(history.currentIndex) else {
            tableView.deselectAll(nil)
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: history.currentIndex), byExtendingSelection: false)
        tableView.scrollRowToVisible(history.currentIndex)
    }
}

private final class NavigationHistoryTableView: NSTableView {
    var onMoveSelection: ((Int) -> Void)?
    var onOpenSelection: ((Bool) -> Void)?
    var onSwitchPane: ((ActivePane) -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case AppKeyCode.leftArrow:
            onSwitchPane?(.left)
        case AppKeyCode.rightArrow:
            onSwitchPane?(.right)
        case AppKeyCode.upArrow:
            onMoveSelection?(-1)
        case AppKeyCode.downArrow:
            onMoveSelection?(1)
        case AppKeyCode.returnKey, AppKeyCode.keypadEnter:
            onOpenSelection?(event.modifierFlags.contains(.shift))
        case AppKeyCode.escape:
            onCancel?()
        default:
            super.keyDown(with: event)
        }
    }
}

private final class NavigationHistoryDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let pathColumnIdentifier = NSUserInterfaceItemIdentifier("navigationHistoryPath")

    var paths: [String] = []
    var theme: DisplayTheme = .light
    private var selectedRow: Int?

    func numberOfRows(in tableView: NSTableView) -> Int {
        paths.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard paths.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("navigationHistoryCell")
        let cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
        let textField = cell.textField ?? NSTextField(labelWithString: "")

        textField.stringValue = paths[row]
        textField.font = .systemFont(ofSize: 13)
        textField.textColor = textColor(for: row)
        textField.lineBreakMode = .byTruncatingMiddle
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

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard paths.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("navigationHistoryRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? ThemedListRowView ?? ThemedListRowView()
        rowView.identifier = identifier
        rowView.rowBackgroundColor = backgroundColor(for: row)
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        let previousRow = selectedRow
        selectedRow = paths.indices.contains(tableView.selectedRow) ? tableView.selectedRow : nil
        refreshRows(tableView: tableView, rows: [previousRow, selectedRow].compactMap { $0 })
    }

    private func refreshRows(tableView: NSTableView, rows: [Int]) {
        let validRows = rows.filter { paths.indices.contains($0) }
        guard !validRows.isEmpty else {
            return
        }

        for row in validRows {
            if let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? ThemedListRowView {
                rowView.rowBackgroundColor = backgroundColor(for: row)
            }
        }
        tableView.reloadData(
            forRowIndexes: IndexSet(validRows),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
    }

    private func backgroundColor(for row: Int) -> NSColor {
        theme.resolvedColorPair(
            isSelected: selectedRow == row,
            isMarked: false,
            isDirectory: false
        ).background?.nsColor ?? (selectedRow == row ? .selectedContentBackgroundColor : .textBackgroundColor)
    }

    private func textColor(for row: Int) -> NSColor {
        theme.resolvedColorPair(
            isSelected: selectedRow == row,
            isMarked: false,
            isDirectory: false
        ).foreground?.nsColor ?? (selectedRow == row ? .selectedTextColor : .labelColor)
    }
}

private final class PathInputFieldDelegate: NSObject, NSTextFieldDelegate {
    private let completionCandidates: (String) -> [String]
    private var activeCandidates: [String] = []
    private var activeCandidateIndex = 0
    private var lastAppliedCandidate: String?

    init(completionCandidates: @escaping (String) -> [String]) {
        self.completionCandidates = completionCandidates
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.insertTab(_:)) else {
            return false
        }

        let currentInput = textView.string
        if currentInput != lastAppliedCandidate {
            activeCandidates = completionCandidates(currentInput)
            activeCandidateIndex = 0
        } else if !activeCandidates.isEmpty {
            activeCandidateIndex = (activeCandidateIndex + 1) % activeCandidates.count
        }

        guard activeCandidates.indices.contains(activeCandidateIndex) else {
            return true
        }

        let completedPath = activeCandidates[activeCandidateIndex]
        textView.string = completedPath
        textView.setSelectedRange(NSRange(location: (completedPath as NSString).length, length: 0))
        control.stringValue = completedPath
        lastAppliedCandidate = completedPath
        return true
    }
}

private enum ActivePane {
    case left
    case right

    var opposite: ActivePane {
        self == .left ? .right : .left
    }

    var messagePrefix: String {
        self == .left ? "L" : "R"
    }

    mutating func toggle() {
        self = opposite
    }
}

private struct CopyConflictPromptResult {
    let resolution: FileCopyConflictResolution
    let appliesToRemaining: Bool
}

private struct MoveConflictPromptResult {
    let resolution: FileMoveConflictResolution
    let appliesToRemaining: Bool
}

private final class ThemedListRowView: NSTableRowView {
    var rowBackgroundColor: NSColor = .textBackgroundColor {
        didSet {
            needsDisplay = true
        }
    }

    override func drawBackground(in dirtyRect: NSRect) {
        rowBackgroundColor.setFill()
        dirtyRect.fill()
    }

    override func drawSelection(in dirtyRect: NSRect) {
        drawBackground(in: dirtyRect)
    }
}

private extension DisplayColor {
    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }
}

private extension FileTagColor {
    var nsColor: NSColor {
        switch self {
        case .gray:
            return NSColor.systemGray
        case .green:
            return NSColor.systemGreen
        case .purple:
            return NSColor.systemPurple
        case .blue:
            return NSColor.systemBlue
        case .yellow:
            return NSColor.systemYellow
        case .red:
            return NSColor.systemRed
        case .orange:
            return NSColor.systemOrange
        }
    }
}

private extension ClipboardCopyFormat {
    var resultMessageKey: String {
        switch self {
        case .fileName:
            return "message.clipboardCopyFileNameResult"
        case .directoryPath:
            return "message.clipboardCopyDirectoryPathResult"
        case .fullPath:
            return "message.clipboardCopyFullPathResult"
        }
    }
}

private extension DisplayTheme {
    var usesContentTransparency: Bool {
        base.background?.paneBackgroundAlpha ?? 1.0 < 1.0
            || message.background?.paneBackgroundAlpha ?? 1.0 < 1.0
    }
}
