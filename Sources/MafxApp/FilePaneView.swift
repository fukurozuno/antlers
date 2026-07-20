import AppKit
import MafxCore

final class FilePaneView: NSView, NSTextFieldDelegate {
    var onActivate: (() -> Void)?
    var onSelectionChange: ((Int) -> Void)?
    var onContextMenuRequest: ((NSPoint) -> Void)?
    var onIncrementalSearchQueryChange: ((String) -> Void)?
    var onIncrementalSearchMove: ((Int) -> Void)?
    var onIncrementalSearchEnd: ((Bool) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")
    private let tagFilterColorMarkerView = TagFilterColorMarkerView()
    private let sortLabel = NSTextField(labelWithString: "")
    private let sortPromptLabel = NSTextField(labelWithString: "")
    private let incrementalSearchField = IncrementalSearchTextField(string: "")
    private let informationLabel = NSTextField(labelWithString: "")
    private let tableView = FilePaneTableView()
    private let scrollView = NSScrollView()
    private let previewService: PreviewService = QuickLookPreviewService()
    private let contentContainer = NSView()
    private let previewContainer = NSView()
    private let previewLoadingCover = NSView()
    private let dataSource = FilePaneDataSource()
    private let tagService = TagService()
    private let informationFormatter = PaneInformationFormatter()
    private var isRendering = false
    private var renderedItems: [FileItem] = []
    private var renderedMarkedItemURLs: Set<URL> = []
    private var renderedSelectedRow: Int?
    private var renderedIsActive = false
    private var renderedTheme: DisplayTheme = .light
    private var renderedUsesAlternatingRowBackgrounds = false
    private var renderedShowsFileIcons = true
    private var renderedShowsFileTagColors = true
    private var renderedShowsFileExtensionsSeparately = true
    private var renderedFileTypeAssociations: [FileTypeAssociation] = []
    private var renderedFileTypeColorScope: FileTypeColorScope = .fileName
    private var topVisibleRow = 0
    private var renderedPreviewItemURL: URL?
    private var previewPresentationState = PreviewPresentationState()

    private struct ScrollPosition {
        let origin: NSPoint
        let topItemURL: URL?
        let topRow: Int
        let topItemOffset: CGFloat
    }

    private static let previewCoverMinimumDuration: DispatchTimeInterval = .milliseconds(150)

    init(title: String) {
        super.init(frame: .zero)
        titleLabel.stringValue = title
        buildView()
        tableView.onMouseDown = { [weak self] in
            self?.onActivate?()
        }
        tableView.onContextMenuRequest = { [weak self] pointInTable in
            guard let self else {
                return
            }

            self.onContextMenuRequest?(self.convert(pointInTable, from: self.tableView))
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(
        state: PaneState,
        isActive: Bool,
        title: String,
        pendingKeySequenceDisplayText: String? = nil,
        usesAlternatingRowBackgrounds: Bool = false,
        showsFileIcons: Bool = true,
        showsFileTagColors: Bool = true,
        showsFileExtensionsSeparately: Bool = true,
        fileTypeAssociations: [FileTypeAssociation] = [],
        fileTypeColorScope: FileTypeColorScope = .fileName,
        theme: DisplayTheme = .light,
        preservesScrollPosition: Bool = false
    ) {
        isRendering = true
        defer { isRendering = false }

        let scrollPosition = preservesScrollPosition ? captureScrollPosition() : nil
        if preservesScrollPosition {
            updateTopVisibleRowFromScrollPosition()
        }

        applyTheme(theme)
        titleLabel.stringValue = title
        pathLabel.stringValue = state.errorMessage ?? state.displayPath
        tagFilterColorMarkerView.isHidden = state.errorMessage != nil || state.tagFilterName == nil
        tagFilterColorMarkerView.markerColor = state.tagFilterColor?.nsColor
        sortLabel.stringValue = L10n.format("pane.sortLabel", state.sortDescriptor.localizedDisplayText)
        if let pendingKeySequenceDisplayText {
            sortPromptLabel.stringValue = L10n.format("pane.pendingKeyPrompt", pendingKeySequenceDisplayText)
            sortPromptLabel.isHidden = false
        } else {
            sortPromptLabel.isHidden = true
        }
        let isSearchInputActive = state.isIncrementalSearchActive
            || state.isWildcardMarkActive
            || state.isFileMaskInputActive
        let searchInputText: String
        if state.isWildcardMarkActive {
            searchInputText = state.wildcardMarkQuery
        } else if state.isFileMaskInputActive {
            searchInputText = state.fileMaskQuery
        } else {
            searchInputText = state.incrementalSearchQuery
        }
        if incrementalSearchField.stringValue != searchInputText {
            incrementalSearchField.stringValue = searchInputText
        }
        if state.isWildcardMarkActive {
            incrementalSearchField.placeholderString = L10n.string("pane.wildcardMark.placeholder")
        } else if state.isFileMaskInputActive {
            incrementalSearchField.placeholderString = L10n.string("pane.fileMask.placeholder")
        } else {
            incrementalSearchField.placeholderString = L10n.string("pane.search.placeholder")
        }
        incrementalSearchField.isHidden = !isSearchInputActive
        informationLabel.stringValue = informationFormatter.string(for: state)
        let isPreviewing = state.isPreviewing
        scrollView.isHidden = isPreviewing
        if let previewItemURL = state.previewItemURL {
            if renderedPreviewItemURL != previewItemURL {
                renderedPreviewItemURL = previewItemURL
                presentPreview(of: previewItemURL)
            }
        } else if renderedPreviewItemURL != nil {
            previewContainer.isHidden = true
            previewLoadingCover.isHidden = true
            renderedPreviewItemURL = nil
            previewPresentationState.endPresentation()
            previewService.endPreview()
        }
        let visibleItems = state.visibleItems
        let visibleSelectedIndex = state.visibleSelectedIndex
        let displayedSelectedIndex = isActive ? visibleSelectedIndex : nil
        let previousSelectedRow = renderedSelectedRow
        if renderedItems != visibleItems
            || renderedMarkedItemURLs != state.markedItemURLs
            || renderedIsActive != isActive
            || renderedUsesAlternatingRowBackgrounds != usesAlternatingRowBackgrounds
            || renderedShowsFileIcons != showsFileIcons
            || renderedShowsFileTagColors != showsFileTagColors
            || renderedShowsFileExtensionsSeparately != showsFileExtensionsSeparately
            || renderedFileTypeAssociations != fileTypeAssociations
            || renderedFileTypeColorScope != fileTypeColorScope
            || renderedTheme != theme {
            dataSource.items = visibleItems
            dataSource.markedItemURLs = state.markedItemURLs
            dataSource.selectedRow = displayedSelectedIndex
            dataSource.theme = theme
            dataSource.usesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
            dataSource.showsFileIcons = showsFileIcons
            dataSource.showsFileTagColors = showsFileTagColors
            dataSource.showsFileExtensionsSeparately = showsFileExtensionsSeparately
            dataSource.fileTypeAssociations = fileTypeAssociations
            dataSource.fileTypeColorScope = fileTypeColorScope
            dataSource.tagColorsByName = Dictionary(
                uniqueKeysWithValues: tagService.tags(in: visibleItems).compactMap { tag in
                    tag.color.map { (tag.name, $0) }
                }
            )
            tableView.reloadData()
            renderedItems = visibleItems
            renderedMarkedItemURLs = state.markedItemURLs
            renderedSelectedRow = displayedSelectedIndex
            renderedIsActive = isActive
            renderedTheme = theme
            renderedUsesAlternatingRowBackgrounds = usesAlternatingRowBackgrounds
            renderedShowsFileIcons = showsFileIcons
            renderedShowsFileTagColors = showsFileTagColors
            renderedShowsFileExtensionsSeparately = showsFileExtensionsSeparately
            renderedFileTypeAssociations = fileTypeAssociations
            renderedFileTypeColorScope = fileTypeColorScope
        } else if previousSelectedRow != displayedSelectedIndex {
            dataSource.selectedRow = displayedSelectedIndex
            updateSelectionRows(previousSelectedRow, displayedSelectedIndex)
            renderedSelectedRow = displayedSelectedIndex
        }

        tableView.tableColumn(withIdentifier: FilePaneDataSource.extensionColumnIdentifier)?.isHidden = !showsFileExtensionsSeparately

        if isActive, let visibleSelectedIndex {
            tableView.selectRowIndexes(IndexSet(integer: visibleSelectedIndex), byExtendingSelection: false)
            if !preservesScrollPosition {
                scrollViewportToContainSelectedRow(visibleSelectedIndex)
            }
        } else {
            tableView.deselectAll(nil)
            topVisibleRow = 0
        }

        if let scrollPosition {
            restoreScrollPosition(scrollPosition, in: visibleItems)
        }

        let focusColors = theme.resolvedFocusColorPair
        let activeBorderColor = focusColors.background?.nsColor ?? .controlAccentColor
        let activeTitleColor = focusColors.foreground?.nsColor ?? activeBorderColor
        layer?.borderWidth = isActive ? 2 : 1
        layer?.borderColor = (isActive ? activeBorderColor : NSColor.separatorColor).cgColor
        titleLabel.textColor = isActive ? activeTitleColor : .labelColor

        if isActive, isSearchInputActive {
            focusIncrementalSearchField()
        }
    }

    private func applyTheme(_ theme: DisplayTheme) {
        let baseColors = theme.resolvedColorPair(isSelected: false, isMarked: false, isDirectory: false)
        let backgroundColor = baseColors.background?.paneBackgroundNSColor ?? .textBackgroundColor
        let foregroundColor = baseColors.foreground?.nsColor ?? .labelColor

        layer?.backgroundColor = backgroundColor.cgColor
        tableView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        titleLabel.backgroundColor = backgroundColor
        pathLabel.backgroundColor = backgroundColor
        sortLabel.backgroundColor = backgroundColor
        sortPromptLabel.backgroundColor = backgroundColor
        informationLabel.backgroundColor = backgroundColor
        pathLabel.textColor = foregroundColor
        sortPromptLabel.textColor = foregroundColor
        informationLabel.textColor = foregroundColor
        incrementalSearchField.drawsBackground = true
        incrementalSearchField.backgroundColor = backgroundColor
        incrementalSearchField.textColor = foregroundColor
        if let cell = incrementalSearchField.cell as? NSTextFieldCell {
            cell.drawsBackground = true
            cell.backgroundColor = backgroundColor
        }
        incrementalSearchField.layer?.backgroundColor = backgroundColor.cgColor
        incrementalSearchField.layer?.borderColor = foregroundColor.cgColor
        previewLoadingCover.layer?.backgroundColor = backgroundColor.cgColor
    }

    func popUpContextMenu(_ menu: NSMenu) {
        let pointInTable: NSPoint
        if tableView.selectedRow >= 0 {
            let rowRect = tableView.rect(ofRow: tableView.selectedRow)
            pointInTable = NSPoint(x: rowRect.minX + 12, y: rowRect.midY)
        } else {
            pointInTable = NSPoint(x: tableView.bounds.minX + 12, y: tableView.bounds.maxY - 12)
        }

        let point = convert(pointInTable, from: tableView)
        menu.popUp(positioning: nil, at: point, in: self)
    }

    func popUpContextMenu(_ menu: NSMenu, at point: NSPoint) {
        menu.popUp(positioning: nil, at: point, in: self)
    }

    var pageScrollRowCount: Int {
        visibleRowCapacity()
    }

    var currentTopVisibleRow: Int {
        topVisibleRow
    }

    func restoreTopVisibleRow(_ row: Int) {
        topVisibleRow = max(0, row)
    }

    func controlTextDidChange(_ notification: Notification) {
        guard let textField = notification.object as? NSTextField,
              !isRendering,
              textField === incrementalSearchField else {
            return
        }

        onIncrementalSearchQueryChange?(incrementalSearchField.stringValue)
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        guard control === incrementalSearchField else {
            return false
        }

        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            onIncrementalSearchEnd?(true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            onIncrementalSearchEnd?(false)
            return true
        case #selector(NSResponder.moveUp(_:)):
            onIncrementalSearchMove?(-1)
            return true
        case #selector(NSResponder.moveDown(_:)):
            onIncrementalSearchMove?(1)
            return true
        default:
            return false
        }
    }

    private func scrollViewportToContainSelectedRow(_ selectedRow: Int) {
        guard tableView.numberOfRows > 0 else {
            topVisibleRow = 0
            return
        }

        let visibleRowCount = visibleRowCapacity()
        let maxTopVisibleRow = max(tableView.numberOfRows - visibleRowCount, 0)
        let previousTopVisibleRow = topVisibleRow
        topVisibleRow = min(topVisibleRow, maxTopVisibleRow)
        let bottomVisibleRow = topVisibleRow + visibleRowCount - 1

        if selectedRow < topVisibleRow {
            topVisibleRow = selectedRow
        } else if selectedRow > bottomVisibleRow {
            topVisibleRow = selectedRow - visibleRowCount + 1
        }

        topVisibleRow = max(0, min(topVisibleRow, maxTopVisibleRow))
        if topVisibleRow != previousTopVisibleRow {
            scrollToTopVisibleRow()
        }
    }

    private func updateSelectionRows(_ rows: Int?...) {
        var rowIndexes = IndexSet()
        for row in rows {
            guard let row, row >= 0, row < tableView.numberOfRows else {
                continue
            }
            rowIndexes.insert(row)
            dataSource.updateRowView(in: tableView, row: row)
        }
        guard !rowIndexes.isEmpty else {
            return
        }

        let columnIndexes = IndexSet(integersIn: 0..<tableView.numberOfColumns)
        tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
    }

    private func visibleRowCapacity() -> Int {
        let rowStride = tableView.rowHeight + tableView.intercellSpacing.height
        guard rowStride > 0, scrollView.contentView.bounds.height > 0 else {
            return 1
        }

        return max(1, Int(floor(scrollView.contentView.bounds.height / rowStride)))
    }

    private func scrollToTopVisibleRow() {
        guard tableView.numberOfRows > 0, tableView.numberOfRows > topVisibleRow else {
            return
        }

        let rowRect = tableView.rect(ofRow: topVisibleRow)
        scrollView.contentView.scroll(to: NSPoint(x: scrollView.contentView.bounds.origin.x, y: rowRect.minY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func updateTopVisibleRowFromScrollPosition() {
        let visibleRows = tableView.rows(in: scrollView.contentView.bounds)
        guard visibleRows.location != NSNotFound else {
            topVisibleRow = 0
            return
        }

        topVisibleRow = visibleRows.location
    }

    private func captureScrollPosition() -> ScrollPosition {
        let origin = scrollView.contentView.bounds.origin
        let visibleRows = tableView.rows(in: scrollView.contentView.bounds)
        let topRow = visibleRows.location == NSNotFound ? 0 : visibleRows.location
        let topItemURL = renderedItems.indices.contains(topRow) ? renderedItems[topRow].url : nil
        let topItemOffset: CGFloat

        if tableView.numberOfRows > topRow {
            topItemOffset = origin.y - tableView.rect(ofRow: topRow).minY
        } else {
            topItemOffset = 0
        }

        return ScrollPosition(
            origin: origin,
            topItemURL: topItemURL,
            topRow: topRow,
            topItemOffset: topItemOffset
        )
    }

    private func restoreScrollPosition(_ position: ScrollPosition, in items: [FileItem]) {
        guard !items.isEmpty else {
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
            topVisibleRow = 0
            return
        }

        let fallbackRow = min(position.topRow, items.count - 1)
        let targetRow = position.topItemURL.flatMap { url in
            items.firstIndex { $0.url == url }
        } ?? fallbackRow
        let targetRect = tableView.rect(ofRow: targetRow)
        let maximumY = max(tableView.bounds.height - scrollView.contentView.bounds.height, 0)
        let targetY = max(0, min(targetRect.minY + position.topItemOffset, maximumY))
        let targetPosition = NSPoint(x: position.origin.x, y: targetY)

        scrollView.contentView.scroll(to: targetPosition)
        scrollView.reflectScrolledClipView(scrollView.contentView)
        updateTopVisibleRowFromScrollPosition()
    }

    private func handleSelectionChange(row: Int) {
        guard !isRendering, row >= 0 else {
            return
        }

        onActivate?()
        onSelectionChange?(row)
    }

    private func presentPreview(of url: URL) {
        let generation = previewPresentationState.beginPresentation(of: url)
        previewLoadingCover.isHidden = false
        previewContainer.isHidden = false
        previewService.showPreview(of: url)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.previewCoverMinimumDuration) { [weak self] in
            guard let self,
                  self.previewPresentationState.shouldRevealPreview(for: url, generation: generation) else {
                return
            }
            self.previewLoadingCover.isHidden = true
        }
    }

    private func buildView() {
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor

        titleLabel.font = .boldSystemFont(ofSize: 13)
        pathLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        pathLabel.lineBreakMode = .byTruncatingMiddle
        tagFilterColorMarkerView.translatesAutoresizingMaskIntoConstraints = false
        sortLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        sortLabel.textColor = .secondaryLabelColor
        sortLabel.lineBreakMode = .byTruncatingTail
        sortPromptLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        sortPromptLabel.textColor = .controlAccentColor
        sortPromptLabel.alignment = .center
        sortPromptLabel.isHidden = true
        incrementalSearchField.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        incrementalSearchField.textColor = .controlAccentColor
        incrementalSearchField.placeholderString = L10n.string("pane.search.placeholder")
        incrementalSearchField.lineBreakMode = .byTruncatingMiddle
        incrementalSearchField.isHidden = true
        incrementalSearchField.isBordered = false
        incrementalSearchField.isBezeled = false
        incrementalSearchField.wantsLayer = true
        incrementalSearchField.layer?.cornerRadius = 4
        incrementalSearchField.layer?.borderWidth = 1
        incrementalSearchField.delegate = self
        incrementalSearchField.translatesAutoresizingMaskIntoConstraints = false
        incrementalSearchField.onMove = { [weak self] delta in
            self?.onIncrementalSearchMove?(delta)
        }
        incrementalSearchField.onEnd = { [weak self] in
            self?.onIncrementalSearchEnd?($0)
        }
        informationLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        informationLabel.textColor = .secondaryLabelColor
        informationLabel.lineBreakMode = .byTruncatingTail
        informationLabel.translatesAutoresizingMaskIntoConstraints = false

        let nameColumn = NSTableColumn(identifier: FilePaneDataSource.nameColumnIdentifier)
        nameColumn.title = L10n.string("pane.column.name")
        nameColumn.resizingMask = .autoresizingMask

        let sizeColumn = NSTableColumn(identifier: FilePaneDataSource.sizeColumnIdentifier)
        sizeColumn.title = L10n.string("pane.column.size")
        sizeColumn.width = 92
        sizeColumn.minWidth = 92
        sizeColumn.maxWidth = 120
        sizeColumn.resizingMask = .userResizingMask

        let extensionColumn = NSTableColumn(identifier: FilePaneDataSource.extensionColumnIdentifier)
        extensionColumn.title = L10n.string("pane.column.extension")
        extensionColumn.width = 92
        extensionColumn.minWidth = 72
        extensionColumn.maxWidth = 140
        extensionColumn.resizingMask = .userResizingMask

        let modifiedColumn = NSTableColumn(identifier: FilePaneDataSource.modifiedColumnIdentifier)
        modifiedColumn.title = L10n.string("pane.column.modified")
        modifiedColumn.width = 176
        modifiedColumn.minWidth = 176
        modifiedColumn.maxWidth = 176
        modifiedColumn.resizingMask = []

        tableView.headerView = nil
        tableView.addTableColumn(nameColumn)
        tableView.addTableColumn(extensionColumn)
        tableView.addTableColumn(sizeColumn)
        tableView.addTableColumn(modifiedColumn)
        tableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        dataSource.onSelectionChange = { [weak self] row in
            self?.handleSelectionChange(row: row)
        }
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = false
        tableView.selectionHighlightStyle = .none
        tableView.rowHeight = 22
        tableView.intercellSpacing = NSSize(width: 0, height: 2)
        tableView.backgroundColor = .clear

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.isHidden = true
        previewService.previewView.translatesAutoresizingMaskIntoConstraints = false
        previewLoadingCover.translatesAutoresizingMaskIntoConstraints = false
        previewLoadingCover.wantsLayer = true
        previewLoadingCover.isHidden = true
        contentContainer.addSubview(scrollView)
        contentContainer.addSubview(previewContainer)
        previewContainer.addSubview(previewService.previewView)
        previewContainer.addSubview(previewLoadingCover)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            previewContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            previewContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            previewContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            previewService.previewView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewService.previewView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewService.previewView.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewService.previewView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor),
            previewLoadingCover.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            previewLoadingCover.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            previewLoadingCover.topAnchor.constraint(equalTo: previewContainer.topAnchor),
            previewLoadingCover.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor)
        ])

        let pathStack = NSStackView(views: [tagFilterColorMarkerView, pathLabel])
        pathStack.orientation = .horizontal
        pathStack.alignment = .centerY
        pathStack.spacing = 5

        let headerStack = NSStackView(views: [titleLabel, pathStack, sortLabel])
        headerStack.orientation = .vertical
        headerStack.spacing = 2
        headerStack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 6, right: 10)

        let rootStack = NSStackView(views: [headerStack, contentContainer, sortPromptLabel, incrementalSearchField])
        rootStack.orientation = .vertical
        rootStack.spacing = 0
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(rootStack)
        addSubview(informationLabel)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: informationLabel.topAnchor),

            tagFilterColorMarkerView.widthAnchor.constraint(equalToConstant: 10),
            tagFilterColorMarkerView.heightAnchor.constraint(equalToConstant: 10),
            incrementalSearchField.heightAnchor.constraint(equalToConstant: 24),

            informationLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            informationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            informationLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            informationLabel.heightAnchor.constraint(equalToConstant: 18)
        ])
    }

    private func focusIncrementalSearchField() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            if window.firstResponder === self.incrementalSearchField {
                return
            }
            if let editor = self.incrementalSearchField.currentEditor(), window.firstResponder === editor {
                return
            }

            window.makeFirstResponder(self.incrementalSearchField)
            self.incrementalSearchField.currentEditor()?.selectedRange = NSRange(
                location: self.incrementalSearchField.stringValue.count,
                length: 0
            )
        }
    }
}

private final class IncrementalSearchTextField: NSTextField {
    var onMove: ((Int) -> Void)?
    var onEnd: ((Bool) -> Void)?

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case SearchKeyCode.returnKey, SearchKeyCode.keypadEnter:
            onEnd?(true)
        case SearchKeyCode.escape:
            onEnd?(false)
        case SearchKeyCode.upArrow:
            onMove?(-1)
        case SearchKeyCode.downArrow:
            onMove?(1)
        default:
            super.keyDown(with: event)
        }
    }
}

private enum SearchKeyCode {
    static let returnKey: UInt16 = 36
    static let keypadEnter: UInt16 = 76
    static let escape: UInt16 = 53
    static let upArrow: UInt16 = 126
    static let downArrow: UInt16 = 125
}

private final class FilePaneTableView: NSTableView {
    var onMouseDown: (() -> Void)?
    var onContextMenuRequest: ((NSPoint) -> Void)?

    override var acceptsFirstResponder: Bool {
        false
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let row = self.row(at: point)
        guard row >= 0 else {
            return
        }

        onMouseDown?()
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        onContextMenuRequest?(point)
    }
}

private final class FilePaneDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    static let nameColumnIdentifier = NSUserInterfaceItemIdentifier("name")
    static let extensionColumnIdentifier = NSUserInterfaceItemIdentifier("extension")
    static let sizeColumnIdentifier = NSUserInterfaceItemIdentifier("size")
    static let modifiedColumnIdentifier = NSUserInterfaceItemIdentifier("modified")

    var items: [FileItem] = []
    var markedItemURLs: Set<URL> = []
    var selectedRow: Int?
    var theme: DisplayTheme = .light
    var usesAlternatingRowBackgrounds = false
    var showsFileIcons = true
    var showsFileTagColors = true
    var showsFileExtensionsSeparately = true
    var fileTypeAssociations: [FileTypeAssociation] = []
    var fileTypeColorScope: FileTypeColorScope = .fileName
    var tagColorsByName: [String: FileTagColor] = [:]
    var onSelectionChange: ((Int) -> Void)?
    private let fileSizeFormatter = FileSizeFormatter()
    private let modifiedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy/MM/dd HH:mm:ss"
        return formatter
    }()

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard items.indices.contains(row) else {
            return nil
        }

        let item = items[row]
        let isSizeColumn = tableColumn?.identifier == Self.sizeColumnIdentifier
        let isExtensionColumn = tableColumn?.identifier == Self.extensionColumnIdentifier
        let isModifiedColumn = tableColumn?.identifier == Self.modifiedColumnIdentifier
        let identifier: NSUserInterfaceItemIdentifier
        if isSizeColumn {
            identifier = NSUserInterfaceItemIdentifier("fileItemSizeCell")
        } else if isExtensionColumn {
            identifier = NSUserInterfaceItemIdentifier("fileItemExtensionCell")
        } else if isModifiedColumn {
            identifier = NSUserInterfaceItemIdentifier("fileItemModifiedCell")
        } else {
            identifier = NSUserInterfaceItemIdentifier("fileItemNameCell")
        }
        let cell: NSTableCellView
        let textField: NSTextField
        if isSizeColumn || isExtensionColumn || isModifiedColumn {
            cell = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? NSTableCellView()
            textField = cell.textField ?? NSTextField(labelWithString: "")
        } else {
            let nameCell = tableView.makeView(withIdentifier: identifier, owner: self) as? FilePaneNameCellView
                ?? FilePaneNameCellView()
            nameCell.identifier = identifier
            nameCell.configure(
                icon: showsFileIcons && !item.isSpecialItem ? NSWorkspace.shared.icon(forFile: item.url.path) : nil,
                tagColor: showsFileTagColors && !item.isSpecialItem ? tagColor(for: item) : nil,
                reservesTagMarkerSpace: !item.isSpecialItem && !showsFileIcons && showsFileTagColors
            )
            cell = nameCell
            textField = nameCell.textField!
        }

        textField.stringValue = text(
            for: item,
            isSizeColumn: isSizeColumn,
            isExtensionColumn: isExtensionColumn,
            isModifiedColumn: isModifiedColumn
        )
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.textColor = textColor(
            for: item,
            row: row,
            isExtensionColumn: isExtensionColumn,
            isNameOrExtensionColumn: !isSizeColumn && !isModifiedColumn
        )
        textField.alignment = isSizeColumn ? .right : .left
        textField.lineBreakMode = isModifiedColumn || isSizeColumn ? .byTruncatingTail : .byTruncatingMiddle
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
        guard items.indices.contains(row) else {
            return nil
        }

        let identifier = NSUserInterfaceItemIdentifier("fileItemRow")
        let rowView = tableView.makeView(withIdentifier: identifier, owner: self) as? FilePaneRowView ?? FilePaneRowView()
        rowView.identifier = identifier
        rowView.rowBackgroundColor = backgroundColor(for: items[row], row: row)
        return rowView
    }

    func updateRowView(in tableView: NSTableView, row: Int) {
        guard items.indices.contains(row),
              let rowView = tableView.rowView(atRow: row, makeIfNecessary: false) as? FilePaneRowView else {
            return
        }

        rowView.rowBackgroundColor = backgroundColor(for: items[row], row: row)
    }

    private func nameText(for item: FileItem, isMarked: Bool) -> String {
        if item.isParentDirectoryItem {
            return ".."
        }

        let markPrefix = isMarked ? "* " : "  "
        let displayName = showsFileExtensionsSeparately ? item.displayBaseName : item.name
        return "\(markPrefix)\(displayName)"
    }

    private func text(
        for item: FileItem,
        isSizeColumn: Bool,
        isExtensionColumn: Bool,
        isModifiedColumn: Bool
    ) -> String {
        if isSizeColumn {
            return sizeText(for: item)
        }

        if isExtensionColumn {
            return extensionText(for: item)
        }

        if isModifiedColumn {
            return modifiedText(for: item)
        }

        return nameText(for: item, isMarked: markedItemURLs.contains(item.url))
    }

    private func backgroundColor(for item: FileItem, row: Int) -> NSColor {
        let pair = theme.resolvedColorPair(
            isSelected: row == selectedRow,
            isMarked: markedItemURLs.contains(item.url),
            isDirectory: item.isDirectory
        )
        let usesBaseBackground = pair.background == theme.base.background
        if row == selectedRow || markedItemURLs.contains(item.url) || !usesBaseBackground {
            return pair.background?.nsColor ?? .textBackgroundColor
        }

        if usesAlternatingRowBackgrounds, !row.isMultiple(of: 2) {
            let baseColor = theme.base.background?.paneBackgroundNSColor ?? .textBackgroundColor
            let tintColor = theme.base.foreground?.nsColor ?? .labelColor
            return baseColor.blended(withFraction: 0.06, of: tintColor) ?? baseColor
        }

        return .clear
    }

    private func textColor(
        for item: FileItem,
        row: Int,
        isExtensionColumn: Bool,
        isNameOrExtensionColumn: Bool
    ) -> NSColor {
        if let color = configuredColor(for: item),
           (fileTypeColorScope == .fileName && isNameOrExtensionColumn)
                || (fileTypeColorScope == .fileExtension && isExtensionColumn) {
            return color.nsColor
        }
        return theme.resolvedColorPair(
            isSelected: row == selectedRow,
            isMarked: markedItemURLs.contains(item.url),
            isDirectory: item.isDirectory
        ).foreground?.nsColor ?? .labelColor
    }

    private func configuredColor(for item: FileItem) -> DisplayColor? {
        guard !item.isDirectory, !item.isSpecialItem else { return nil }
        return fileTypeAssociations.first { $0.matches(fileExtension: item.url.pathExtension) }?.color
    }

    private func sizeText(for item: FileItem) -> String {
        guard !item.isDirectory, let byteSize = item.byteSize else {
            return ""
        }

        return fileSizeFormatter.string(fromByteCount: byteSize)
    }

    private func modifiedText(for item: FileItem) -> String {
        guard let modificationDate = item.modificationDate else {
            return ""
        }

        return modifiedDateFormatter.string(from: modificationDate)
    }

    private func extensionText(for item: FileItem) -> String {
        if item.isParentDirectoryItem {
            return ""
        }

        return item.isDirectory ? "<DIR>" : item.displayFileExtension
    }

    private func tagColor(for item: FileItem) -> NSColor? {
        item.tagNames
            .compactMap(FileTag.init(resourceValue:))
            .compactMap { tag in
                tag.color ?? tagColorsByName[tag.name]
            }
            .first?
            .nsColor
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView = notification.object as? NSTableView else {
            return
        }

        onSelectionChange?(tableView.selectedRow)
    }
}

private final class FilePaneNameCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let tagMarkerView = TagColorMarkerView()
    private var textLeadingWithIcon: NSLayoutConstraint!
    private var textLeadingWithTagMarker: NSLayoutConstraint!
    private var textLeadingWithoutAccessory: NSLayoutConstraint!
    private var tagMarkerTrailingToIcon: NSLayoutConstraint!
    private var tagMarkerLeadingToCell: NSLayoutConstraint!
    private var tagMarkerWidth: NSLayoutConstraint!
    private var tagMarkerHeight: NSLayoutConstraint!

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        let label = NSTextField(labelWithString: "")
        textField = label
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        tagMarkerView.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconView)
        addSubview(tagMarkerView)
        addSubview(label)
        textLeadingWithIcon = label.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6)
        textLeadingWithTagMarker = label.leadingAnchor.constraint(equalTo: tagMarkerView.trailingAnchor, constant: 6)
        textLeadingWithoutAccessory = label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8)
        tagMarkerTrailingToIcon = tagMarkerView.trailingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 1)
        tagMarkerLeadingToCell = tagMarkerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10)
        tagMarkerWidth = tagMarkerView.widthAnchor.constraint(equalToConstant: 8)
        tagMarkerHeight = tagMarkerView.heightAnchor.constraint(equalToConstant: 8)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),
            tagMarkerView.bottomAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 1),
            tagMarkerWidth,
            tagMarkerHeight,
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        textLeadingWithoutAccessory.isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(icon: NSImage?, tagColor: NSColor?, reservesTagMarkerSpace: Bool) {
        iconView.image = icon
        iconView.isHidden = icon == nil
        tagMarkerView.markerColor = tagColor
        let showsIcon = icon != nil
        let showsTagMarker = tagColor != nil
        let usesTagMarkerSpace = !showsIcon && reservesTagMarkerSpace
        tagMarkerView.isHidden = !showsTagMarker
        tagMarkerTrailingToIcon.isActive = showsIcon && showsTagMarker
        tagMarkerLeadingToCell.isActive = usesTagMarkerSpace
        tagMarkerWidth.constant = showsIcon ? 8 : 14
        tagMarkerHeight.constant = showsIcon ? 8 : 14
        textLeadingWithIcon.isActive = showsIcon
        textLeadingWithTagMarker.isActive = usesTagMarkerSpace
        textLeadingWithoutAccessory.isActive = !showsIcon && !usesTagMarkerSpace
    }
}

private final class TagColorMarkerView: NSView {
    var markerColor: NSColor? {
        didSet {
            needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        NSColor.windowBackgroundColor.setFill()
        NSBezierPath(ovalIn: bounds).fill()
        markerColor?.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1.25, dy: 1.25)).fill()
    }
}

private final class FilePaneRowView: NSTableRowView {
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

private final class TagFilterColorMarkerView: NSView {
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

private extension DisplayColor {
    var nsColor: NSColor {
        NSColor(calibratedRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1.0)
    }

    var paneBackgroundNSColor: NSColor {
        NSColor(
            calibratedRed: CGFloat(red),
            green: CGFloat(green),
            blue: CGFloat(blue),
            alpha: CGFloat(paneBackgroundAlpha)
        )
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
