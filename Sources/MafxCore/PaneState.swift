import Foundation

public struct PaneState: Equatable {
    private struct ArchiveBrowsingState: Equatable {
        let archiveURL: URL
        let archiveName: String
        let entries: [ArchiveEntryInfo]
        var directoryPath: String
    }

    public private(set) var currentDirectory: URL
    public private(set) var items: [FileItem]
    public private(set) var selectedIndex: Int
    public private(set) var markedItemURLs: Set<URL>
    public private(set) var sortDescriptor: FileSortDescriptor
    public private(set) var showsHiddenFiles: Bool
    public private(set) var incrementalSearchQuery: String
    public private(set) var isIncrementalSearchActive: Bool
    public private(set) var incrementalSearchMatchMode: IncrementalSearchMatchMode
    public private(set) var wildcardMarkQuery: String
    public private(set) var isWildcardMarkActive: Bool
    public private(set) var fileMaskQuery: String
    public private(set) var isFileMaskInputActive: Bool
    public private(set) var fileMaskPattern: String
    public private(set) var tagFilterName: String?
    public private(set) var tagFilterColor: FileTagColor?
    public private(set) var paneWidthRatio: Double
    public private(set) var messageWindowHeightRatio: Double
    public private(set) var messageLines: [String]
    public private(set) var transientOperationMessage: String?
    public private(set) var navigationHistory: NavigationHistory
    public private(set) var errorMessage: String?
    public private(set) var previewItemURL: URL?
    public private(set) var previewStartTopVisibleRow: Int?
    public let fileSystemScope: FileSystemScope
    private var archiveBrowsingState: ArchiveBrowsingState?

    public init(
        currentDirectory: URL,
        items: [FileItem] = [],
        selectedIndex: Int = 0,
        markedItemURLs: Set<URL> = [],
        sortDescriptor: FileSortDescriptor = .default,
        showsHiddenFiles: Bool = false,
        incrementalSearchQuery: String = "",
        isIncrementalSearchActive: Bool = false,
        incrementalSearchMatchMode: IncrementalSearchMatchMode = .prefix,
        wildcardMarkQuery: String = "",
        isWildcardMarkActive: Bool = false,
        fileMaskQuery: String = "",
        isFileMaskInputActive: Bool = false,
        fileMaskPattern: String = "",
        tagFilterName: String? = nil,
        tagFilterColor: FileTagColor? = nil,
        paneWidthRatio: Double = 0.5,
        messageWindowHeightRatio: Double = 0.2,
        messageLines: [String] = [],
        transientOperationMessage: String? = nil,
        navigationHistory: NavigationHistory = NavigationHistory(),
        errorMessage: String? = nil,
        previewItemURL: URL? = nil,
        previewStartTopVisibleRow: Int? = nil,
        fileSystemScope: FileSystemScope = .unrestricted
    ) {
        self.currentDirectory = currentDirectory
        self.items = items
        self.selectedIndex = selectedIndex
        self.markedItemURLs = markedItemURLs
        self.sortDescriptor = sortDescriptor
        self.showsHiddenFiles = showsHiddenFiles
        self.incrementalSearchQuery = incrementalSearchQuery
        self.isIncrementalSearchActive = isIncrementalSearchActive
        self.incrementalSearchMatchMode = incrementalSearchMatchMode
        self.wildcardMarkQuery = wildcardMarkQuery
        self.isWildcardMarkActive = isWildcardMarkActive
        self.fileMaskQuery = fileMaskQuery
        self.isFileMaskInputActive = isFileMaskInputActive
        self.fileMaskPattern = fileMaskPattern
        self.tagFilterName = tagFilterName
        self.tagFilterColor = tagFilterColor
        self.paneWidthRatio = Self.clampedPaneWidthRatio(paneWidthRatio)
        self.messageWindowHeightRatio = Self.clampedMessageWindowHeightRatio(messageWindowHeightRatio)
        self.messageLines = messageLines
        self.transientOperationMessage = transientOperationMessage
        self.navigationHistory = navigationHistory.prepared(for: currentDirectory)
        self.errorMessage = errorMessage
        self.previewItemURL = previewItemURL
        self.previewStartTopVisibleRow = previewStartTopVisibleRow
        self.fileSystemScope = fileSystemScope
        self.archiveBrowsingState = nil
    }

    public var visibleItems: [FileItem] {
        items.filter(matchesActiveFilters)
    }

    public var displayPath: String {
        if let archiveBrowsingState {
            return archiveBrowsingState.directoryPath.isEmpty
                ? archiveBrowsingState.archiveName
                : "\(archiveBrowsingState.archiveName)/\(archiveBrowsingState.directoryPath)"
        }
        if let tagFilterName {
            return "タグ: \(tagFilterName)"
        }

        return currentDirectory.path
    }

    public var isBrowsingArchive: Bool {
        archiveBrowsingState != nil
    }

    /// ZIP 表示中に選択している仮想項目の参照です。通常のファイル操作に URL として渡してはいけません。
    public var selectedArchiveEntryReference: ArchiveEntryReference? {
        guard let archiveBrowsingState, let selectedItem else { return nil }
        let path = archiveBrowsingState.directoryPath + selectedItem.name + (selectedItem.isDirectory ? "/" : "")
        return ArchiveEntryReference(
            archiveURL: archiveBrowsingState.archiveURL,
            entryPath: path,
            isDirectory: selectedItem.isDirectory
        )
    }

    public var visibleSelectedIndex: Int? {
        visibleItems.firstIndex { $0 == selectedListItem }
    }

    public var selectedListItem: FileItem? {
        guard items.indices.contains(selectedIndex) else {
            return nil
        }

        let item = items[selectedIndex]
        guard matchesActiveFilters(item) else {
            return nil
        }

        return item
    }

    public var selectedItem: FileItem? {
        guard let selectedListItem, !selectedListItem.isSpecialItem else {
            return nil
        }

        return selectedListItem
    }

    public var selectedItemByteSize: Int64? {
        selectedItem?.byteSize
    }

    public var markedItems: [FileItem] {
        items.filter { markedItemURLs.contains($0.url) }
    }

    /// クリップボード操作の対象です。マーク済み項目を優先し、マークがない場合は選択中の一覧項目を返します。
    public var clipboardCopyTargetItems: [FileItem] {
        if !markedItems.isEmpty {
            return markedItems
        }

        return selectedListItem.map { [$0] } ?? []
    }

    public var isPreviewing: Bool {
        previewItemURL != nil
    }

    @discardableResult
    public mutating func beginPreviewForSelectedFile(topVisibleRow: Int) -> Bool {
        guard let selectedItem, !selectedItem.isDirectory else {
            return false
        }

        previewItemURL = selectedItem.url
        previewStartTopVisibleRow = max(0, topVisibleRow)
        return true
    }

    @discardableResult
    public mutating func endPreview() -> Int? {
        guard previewItemURL != nil else {
            return nil
        }

        previewItemURL = nil
        defer { previewStartTopVisibleRow = nil }
        return previewStartTopVisibleRow
    }

    @discardableResult
    public mutating func movePreviewSelection(by delta: Int) -> Bool {
        guard previewItemURL != nil, delta != 0 else {
            return false
        }

        let visibleFileIndexes = visibleItemIndexes().filter { !items[$0].isDirectory }
        guard !visibleFileIndexes.isEmpty else {
            return false
        }

        let currentFileIndex = visibleFileIndexes.firstIndex(of: selectedIndex)
            ?? (delta < 0 ? visibleFileIndexes.count : -1)
        let nextFileIndex = max(0, min(visibleFileIndexes.count - 1, currentFileIndex + delta))
        selectedIndex = visibleFileIndexes[nextFileIndex]
        previewItemURL = items[selectedIndex].url
        return true
    }

    public mutating func toggleMarkForPreviewedFile(moveSelectionBy delta: Int = 0) {
        guard previewItemURL != nil else {
            return
        }

        toggleMarkForSelectedItem()
        if delta != 0 {
            _ = movePreviewSelection(by: delta)
        }
    }

    public mutating func loadCurrentDirectory(using service: DirectoryListingProviding) {
        guard archiveBrowsingState == nil else {
            return
        }
        items = FileItem.parentDirectoryItem(for: currentDirectory).map { [$0] } ?? []
        do {
            items += try service.contents(of: currentDirectory, includingHiddenFiles: showsHiddenFiles)
                .filter { !$0.isSpecialItem }
            applyCurrentSort()
            discardMarksForItemsNoLongerListed()
            clampSelectionToVisibleItems()
            errorMessage = nil
        } catch {
            items = []
            selectedIndex = 0
            errorMessage = error.localizedDescription
        }
    }

    public mutating func reloadCurrentDirectory(using service: DirectoryListingProviding) {
        guard archiveBrowsingState == nil else {
            return
        }
        let selectedItemURL = selectedItem?.url
        loadCurrentDirectory(using: service)

        guard let selectedItemURL,
              let selectedIndex = items.firstIndex(where: { $0.url == selectedItemURL }),
              matchesActiveFilters(items[selectedIndex]) else {
            return
        }

        self.selectedIndex = selectedIndex
    }

    public mutating func setShowsHiddenFiles(_ showsHiddenFiles: Bool, using service: DirectoryListingProviding) {
        guard self.showsHiddenFiles != showsHiddenFiles else {
            return
        }

        self.showsHiddenFiles = showsHiddenFiles
        loadCurrentDirectory(using: service)
    }

    public mutating func setPaneWidthRatio(_ ratio: Double) {
        paneWidthRatio = Self.clampedPaneWidthRatio(ratio)
    }

    public mutating func adjustPaneWidthRatio(by delta: Double) {
        setPaneWidthRatio(paneWidthRatio + delta)
    }

    public mutating func setMessageWindowHeightRatio(_ ratio: Double) {
        messageWindowHeightRatio = Self.clampedMessageWindowHeightRatio(ratio)
    }

    public mutating func adjustMessageWindowHeightRatio(by delta: Double) {
        setMessageWindowHeightRatio(messageWindowHeightRatio + delta)
    }

    public mutating func appendMessage(_ message: String) {
        guard !message.isEmpty else {
            return
        }

        messageLines.append(message)
        if messageLines.count > 200 {
            messageLines.removeFirst(messageLines.count - 200)
        }
    }

    public mutating func setTransientOperationMessage(_ message: String?) {
        transientOperationMessage = message?.isEmpty == true ? nil : message
    }

    public mutating func moveSelection(by delta: Int) {
        let visibleIndexes = visibleItemIndexes()
        guard !visibleIndexes.isEmpty else {
            selectedIndex = 0
            return
        }

        let currentVisibleIndex = visibleIndexes.firstIndex(of: selectedIndex)
            ?? (delta < 0 ? visibleIndexes.count : -1)
        let nextVisibleIndex = max(0, min(visibleIndexes.count - 1, currentVisibleIndex + delta))
        selectedIndex = visibleIndexes[nextVisibleIndex]
    }

    public mutating func moveSelectionByPage(direction: Int, visibleRowCount: Int) {
        guard direction != 0 else {
            return
        }

        let pageDistance = max(1, visibleRowCount - 1)
        moveSelection(by: direction < 0 ? -pageDistance : pageDistance)
    }

    public mutating func selectItem(at index: Int) {
        guard items.indices.contains(index) else {
            return
        }

        selectedIndex = index
    }

    public mutating func selectItem(withURL url: URL) {
        guard let index = items.firstIndex(where: { $0.url == url }) else {
            return
        }

        selectedIndex = index
    }

    public mutating func selectVisibleItem(at index: Int) {
        let visibleIndexes = visibleItemIndexes()
        guard visibleIndexes.indices.contains(index) else {
            return
        }

        selectedIndex = visibleIndexes[index]
    }

    public mutating func toggleMarkForSelectedItem(moveSelectionBy delta: Int = 0) {
        if selectedListItem?.isSpecialItem == true {
            if delta != 0 {
                moveSelection(by: delta)
            }
            return
        }

        guard let selectedItem else {
            return
        }

        if markedItemURLs.contains(selectedItem.url) {
            markedItemURLs.remove(selectedItem.url)
        } else {
            markedItemURLs.insert(selectedItem.url)
        }

        if delta != 0 {
            moveSelection(by: delta)
        }
    }

    public mutating func markRangeFromPreviousMarkedItemToSelectedItem() {
        let visibleIndexes = visibleItemIndexes()
        guard let selectedVisibleIndex = visibleIndexes.firstIndex(of: selectedIndex) else {
            return
        }

        let previousMarkedVisibleIndex = visibleIndexes[..<selectedVisibleIndex].lastIndex {
            markedItemURLs.contains(items[$0].url)
        }
        guard let previousMarkedVisibleIndex else {
            return
        }

        let rangeURLs = visibleIndexes[previousMarkedVisibleIndex...selectedVisibleIndex]
            .map { items[$0] }
            .filter { !$0.isSpecialItem }
            .map(\.url)
        markedItemURLs.formUnion(rangeURLs)
    }

    public mutating func invertMarkedFiles(includingDirectories: Bool = false) {
        let targetURLs = Set(visibleItems
            .filter { !$0.isSpecialItem }
            .filter { includingDirectories || !$0.isDirectory }
            .map(\.url))
        let markedTargetURLs = markedItemURLs.intersection(targetURLs)

        if markedTargetURLs.isEmpty {
            markedItemURLs = targetURLs
        } else {
            markedItemURLs = targetURLs.subtracting(markedTargetURLs)
        }
    }

    @discardableResult
    public mutating func markSameNamedFiles(
        comparedWith oppositeItems: [FileItem],
        options: SameNamedFileMarkOptions = SameNamedFileMarkOptions()
    ) -> Int {
        let oppositeFilesByName = Dictionary(
            grouping: oppositeItems.filter { !$0.isSpecialItem && !$0.isDirectory },
            by: \.name
        )
        let matchingURLs = visibleItems
            .filter { !$0.isSpecialItem && !$0.isDirectory }
            .filter { item in
                guard let oppositeFiles = oppositeFilesByName[item.name] else {
                    return false
                }

                return oppositeFiles.contains { oppositeItem in
                    sameNamedFile(item, matches: oppositeItem, options: options)
                }
            }
            .map(\.url)

        markedItemURLs.formUnion(matchingURLs)
        return matchingURLs.count
    }

    public mutating func beginIncrementalSearch() {
        endWildcardMark()
        endFileMaskInput()
        isIncrementalSearchActive = true
        incrementalSearchQuery = ""
    }

    public mutating func endIncrementalSearch() {
        isIncrementalSearchActive = false
        incrementalSearchQuery = ""
    }

    public mutating func appendIncrementalSearchText(_ text: String) {
        guard isIncrementalSearchActive, !text.isEmpty else {
            return
        }

        updateIncrementalSearchQuery(incrementalSearchQuery + text)
    }

    public mutating func updateIncrementalSearchQuery(_ query: String) {
        guard isIncrementalSearchActive else {
            return
        }

        incrementalSearchQuery = query
        selectNextSearchMatch(offset: 0)
    }

    public mutating func setIncrementalSearchMatchMode(_ mode: IncrementalSearchMatchMode) {
        incrementalSearchMatchMode = mode
        selectNextSearchMatch(offset: 0)
    }

    public mutating func deleteLastIncrementalSearchCharacter() {
        guard isIncrementalSearchActive, !incrementalSearchQuery.isEmpty else {
            return
        }

        updateIncrementalSearchQuery(String(incrementalSearchQuery.dropLast()))
    }

    public mutating func selectNextIncrementalSearchMatch() {
        selectNextSearchMatch(offset: 1)
    }

    public mutating func selectPreviousIncrementalSearchMatch() {
        selectNextSearchMatch(offset: -1)
    }

    public mutating func beginWildcardMark() {
        endIncrementalSearch()
        endFileMaskInput()
        isWildcardMarkActive = true
        wildcardMarkQuery = ""
    }

    public mutating func endWildcardMark() {
        isWildcardMarkActive = false
        wildcardMarkQuery = ""
    }

    public mutating func updateWildcardMarkQuery(_ query: String) {
        guard isWildcardMarkActive else {
            return
        }

        wildcardMarkQuery = query
        selectNextWildcardMarkMatch(offset: 0)
    }

    public mutating func selectNextWildcardMarkMatch() {
        selectNextWildcardMarkMatch(offset: 1)
    }

    public mutating func selectPreviousWildcardMarkMatch() {
        selectNextWildcardMarkMatch(offset: -1)
    }

    public mutating func markWildcardMatchesAndEnd() {
        guard isWildcardMarkActive else {
            return
        }

        if !wildcardMarkQuery.isEmpty {
            let matchingURLs = items
                .filter(matchesActiveFilters)
                .filter { !$0.isSpecialItem }
                .filter { FileNameWildcardMatcher.matches($0.name, pattern: wildcardMarkQuery, mode: .exactWildcard) }
                .map(\.url)
            markedItemURLs.formUnion(matchingURLs)
        }

        endWildcardMark()
    }

    public mutating func beginFileMaskInput() {
        endIncrementalSearch()
        endWildcardMark()
        isFileMaskInputActive = true
        fileMaskQuery = ""
    }

    public mutating func endFileMaskInput() {
        isFileMaskInputActive = false
        fileMaskQuery = ""
    }

    public mutating func updateFileMaskQuery(_ query: String) {
        guard isFileMaskInputActive else {
            return
        }

        fileMaskQuery = query
        selectNextFileMaskInputMatch(offset: 0)
    }

    public mutating func selectNextFileMaskInputMatch() {
        selectNextFileMaskInputMatch(offset: 1)
    }

    public mutating func selectPreviousFileMaskInputMatch() {
        selectNextFileMaskInputMatch(offset: -1)
    }

    public mutating func applyFileMaskAndEnd() {
        guard isFileMaskInputActive else {
            return
        }

        fileMaskPattern = fileMaskQuery
        endFileMaskInput()
        clampSelectionToVisibleItems()
    }

    public mutating func clearFileMask() {
        fileMaskPattern = ""
        if isFileMaskInputActive {
            fileMaskQuery = ""
        }
        clampSelectionToVisibleItems()
    }

    public mutating func applyTagFilter(_ tag: FileTag) {
        tagFilterName = tag.name
        tagFilterColor = tag.color
        endIncrementalSearch()
        endWildcardMark()
        endFileMaskInput()
        clampSelectionToVisibleItems()
    }

    public mutating func applyTagSearchResults(_ searchResults: [FileItem], tag: FileTag) {
        items = searchResults
        selectedIndex = 0
        clearMarkedItems()
        tagFilterName = tag.name
        tagFilterColor = tag.color
        endIncrementalSearch()
        endWildcardMark()
        clearFileMask()
        endFileMaskInput()
        applyCurrentSort()
        clampSelectionToVisibleItems()
        errorMessage = nil
    }

    public mutating func clearTagFilter() {
        tagFilterName = nil
        tagFilterColor = nil
        clampSelectionToVisibleItems()
    }

    public mutating func applySort(_ criterion: FileSortCriterion) {
        let selectedURL = selectedItem?.url
        sortDescriptor = sortDescriptor.toggled(ifSameAs: criterion)
        applyCurrentSort()

        if let selectedURL, let newIndex = items.firstIndex(where: { $0.url == selectedURL }) {
            selectedIndex = newIndex
        } else {
            selectedIndex = items.isEmpty ? 0 : min(selectedIndex, items.count - 1)
        }
        clampSelectionToVisibleItems()
    }

    @discardableResult
    public mutating func enterSelectedDirectory(
        selectingPreviousDirectory: Bool = true,
        using service: DirectoryListingProviding
    ) -> Bool {
        guard let selectedListItem else {
            return false
        }

        if archiveBrowsingState != nil {
            if selectedListItem.isParentDirectoryItem {
                return moveToParentDirectory(using: service)
            }
            guard selectedListItem.isDirectory else { return false }
            enterArchiveDirectory(named: selectedListItem.name)
            return true
        }

        if selectedListItem.isParentDirectoryItem {
            return moveToParentDirectory(
                selectingPreviousDirectory: selectingPreviousDirectory,
                using: service
            )
        }

        guard selectedListItem.isDirectory else {
            return false
        }

        currentDirectory = selectedListItem.url
        selectedIndex = 0
        clearMarkedItems()
        clearFileMask()
        clearTagFilter()
        loadCurrentDirectory(using: service)
        navigationHistory.record(currentDirectory)
        return true
    }

    @discardableResult
    public mutating func moveToParentDirectory(
        selectingPreviousDirectory: Bool = true,
        using service: DirectoryListingProviding
    ) -> Bool {
        if archiveBrowsingState != nil {
            return moveArchiveToParent(using: service)
        }
        let previousDirectory = currentDirectory
        let parentDirectory = URL(fileURLWithPath: currentDirectory.deletingLastPathComponent().path)
        guard parentDirectory != currentDirectory else {
            return false
        }
        guard fileSystemScope.contains(parentDirectory) else {
            return false
        }

        currentDirectory = parentDirectory
        selectedIndex = 0
        clearMarkedItems()
        clearFileMask()
        clearTagFilter()
        loadCurrentDirectory(using: service)
        if selectingPreviousDirectory {
            selectItem(withURL: previousDirectory)
        }
        navigationHistory.record(currentDirectory)
        return true
    }

    public mutating func moveToDirectory(
        _ directory: URL,
        using service: DirectoryListingProviding,
        recordsHistory: Bool = true
    ) {
        guard fileSystemScope.contains(directory) else {
            return
        }
        archiveBrowsingState = nil
        currentDirectory = directory
        selectedIndex = 0
        clearMarkedItems()
        endIncrementalSearch()
        endWildcardMark()
        clearFileMask()
        clearTagFilter()
        endFileMaskInput()
        loadCurrentDirectory(using: service)
        if recordsHistory {
            navigationHistory.record(currentDirectory)
        }
    }

    @discardableResult
    public mutating func moveBackwardInHistory(using service: DirectoryListingProviding) -> Bool {
        guard let directory = navigationHistory.moveBackward() else {
            return false
        }

        moveToDirectory(directory, using: service, recordsHistory: false)
        return true
    }

    @discardableResult
    public mutating func moveForwardInHistory(using service: DirectoryListingProviding) -> Bool {
        guard let directory = navigationHistory.moveForward() else {
            return false
        }

        moveToDirectory(directory, using: service, recordsHistory: false)
        return true
    }

    @discardableResult
    public mutating func moveToHistoryPath(at index: Int, using service: DirectoryListingProviding) -> Bool {
        guard let directory = navigationHistory.moveToPath(at: index) else {
            return false
        }

        moveToDirectory(directory, using: service, recordsHistory: false)
        return true
    }

    public mutating func clearMarkedItems() {
        markedItemURLs.removeAll()
    }

    public mutating func beginArchiveBrowsing(archiveURL: URL, entries: [ArchiveEntryInfo]) {
        archiveBrowsingState = ArchiveBrowsingState(
            archiveURL: archiveURL,
            archiveName: archiveURL.lastPathComponent,
            entries: entries,
            directoryPath: ""
        )
        selectedIndex = 0
        clearMarkedItems()
        endIncrementalSearch()
        endWildcardMark()
        clearFileMask()
        clearTagFilter()
        endFileMaskInput()
        loadArchiveDirectoryItems()
        errorMessage = nil
    }

    /// 指定した項目のマークだけを解除します。
    /// ファイル操作の項目別実行結果を反映するために使用します。
    public mutating func unmarkItems(at urls: some Sequence<URL>) {
        let normalizedURLs = Set(urls.map { $0.standardizedFileURL })
        markedItemURLs = markedItemURLs.filter { !normalizedURLs.contains($0.standardizedFileURL) }
    }

    private mutating func discardMarksForItemsNoLongerListed() {
        let listedItemURLs = Set(items
            .filter { !$0.isSpecialItem }
            .map(\.url))
        markedItemURLs.formIntersection(listedItemURLs)
    }

    private mutating func enterArchiveDirectory(named name: String) {
        guard var archiveBrowsingState else { return }
        archiveBrowsingState.directoryPath += name + "/"
        self.archiveBrowsingState = archiveBrowsingState
        selectedIndex = 0
        loadArchiveDirectoryItems()
    }

    private mutating func moveArchiveToParent(using service: DirectoryListingProviding) -> Bool {
        guard var archiveBrowsingState else { return false }
        if archiveBrowsingState.directoryPath.isEmpty {
            let archiveURL = archiveBrowsingState.archiveURL
            self.archiveBrowsingState = nil
            selectedIndex = 0
            loadCurrentDirectory(using: service)
            selectItem(withURL: archiveURL)
            return true
        }

        let components = archiveBrowsingState.directoryPath.split(separator: "/")
        archiveBrowsingState.directoryPath = components.dropLast().joined(separator: "/")
        if !archiveBrowsingState.directoryPath.isEmpty {
            archiveBrowsingState.directoryPath += "/"
        }
        self.archiveBrowsingState = archiveBrowsingState
        selectedIndex = 0
        loadArchiveDirectoryItems()
        return true
    }

    private mutating func loadArchiveDirectoryItems() {
        guard let archiveBrowsingState else { return }
        let prefix = archiveBrowsingState.directoryPath
        var children: [String: (isDirectory: Bool, byteSize: Int64)] = [:]
        for entry in archiveBrowsingState.entries where entry.path.hasPrefix(prefix) {
            let remainder = String(entry.path.dropFirst(prefix.count))
            guard !remainder.isEmpty else { continue }
            let components = remainder.split(separator: "/", omittingEmptySubsequences: true)
            guard let first = components.first else { continue }
            let name = String(first)
            let isDirectory = components.count > 1 || entry.isDirectory
            let path = prefix + name + (isDirectory ? "/" : "")
            if children[path] == nil {
                children[path] = (isDirectory, entry.uncompressedSize)
            }
        }

        let parentItem: [FileItem]
        if prefix.isEmpty {
            parentItem = []
        } else {
            parentItem = [FileItem(
                url: archiveVirtualURL(for: ".."),
                isDirectory: true,
                name: "..",
                kind: .parentDirectory
            )]
        }
        items = parentItem + children
            .map { path, value in
                FileItem(
                    url: archiveVirtualURL(for: path),
                    isDirectory: value.isDirectory,
                    name: String(path.split(separator: "/").last ?? ""),
                    byteSize: value.isDirectory ? nil : value.byteSize
                )
            }
            .sorted {
                if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
        clampSelectionToVisibleItems()
    }

    private func archiveVirtualURL(for path: String) -> URL {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        return URL(string: "mafx-archive://entry/\(encodedPath)")!
    }

    private mutating func selectNextSearchMatch(offset: Int) {
        guard isIncrementalSearchActive, !incrementalSearchQuery.isEmpty, !visibleItems.isEmpty else {
            return
        }

        selectNextMatch(pattern: incrementalSearchQuery, mode: .incrementalSearch(incrementalSearchMatchMode), offset: offset)
    }

    private mutating func selectNextWildcardMarkMatch(offset: Int) {
        guard isWildcardMarkActive, !wildcardMarkQuery.isEmpty, !visibleItems.isEmpty else {
            return
        }

        selectNextMatch(pattern: wildcardMarkQuery, mode: .exactWildcard, offset: offset)
    }

    private mutating func selectNextFileMaskInputMatch(offset: Int) {
        guard isFileMaskInputActive, !fileMaskQuery.isEmpty, !items.isEmpty else {
            return
        }

        selectNextMatch(pattern: fileMaskQuery, mode: .exactWildcard, offset: offset)
    }

    private mutating func selectNextMatch(pattern: String, mode: FileNameMatchMode, offset: Int) {
        let candidateIndexes = visibleItemIndexes(matching: pattern, mode: mode)
        guard !candidateIndexes.isEmpty else {
            return
        }

        if offset == 0 {
            selectedIndex = candidateIndexes.first { $0 >= selectedIndex } ?? candidateIndexes[0]
            return
        }

        let direction = offset < 0 ? -1 : 1
        let currentMatchIndex = candidateIndexes.firstIndex(of: selectedIndex)
            ?? (direction < 0 ? candidateIndexes.count : -1)
        let matchIndex = wrappedIndex(currentMatchIndex + offset, count: candidateIndexes.count)
        selectedIndex = candidateIndexes[matchIndex]
    }

    private func wrappedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else {
            return 0
        }

        return (index % count + count) % count
    }

    private mutating func applyCurrentSort() {
        let specialItems = items.filter(\.isSpecialItem)
        var regularItems = items.filter { !$0.isSpecialItem }
        regularItems.sort(using: sortDescriptor)
        items = specialItems + regularItems
    }

    private func matchesActiveFileMask(_ item: FileItem) -> Bool {
        guard !item.isSpecialItem else {
            return true
        }

        guard !fileMaskPattern.isEmpty else {
            return true
        }

        return FileNameWildcardMatcher.matches(item.name, pattern: fileMaskPattern, mode: .exactWildcard)
    }

    private func matchesActiveTagFilter(_ item: FileItem) -> Bool {
        guard !item.isSpecialItem else {
            return true
        }

        guard let tagFilterName else {
            return true
        }

        return item.tagNames.contains(tagFilterName)
    }

    private func matchesActiveFilters(_ item: FileItem) -> Bool {
        matchesActiveFileMask(item) && matchesActiveTagFilter(item)
    }

    private func visibleItemIndexes() -> [Int] {
        items.indices.filter { matchesActiveFilters(items[$0]) }
    }

    private func visibleItemIndexes(matching pattern: String, mode: FileNameMatchMode) -> [Int] {
        visibleItemIndexes().filter {
            !items[$0].isSpecialItem
                && FileNameWildcardMatcher.matches(items[$0].name, pattern: pattern, mode: mode)
        }
    }

    private mutating func clampSelectionToVisibleItems() {
        let visibleIndexes = visibleItemIndexes()
        guard !visibleIndexes.isEmpty else {
            selectedIndex = 0
            return
        }

        if !visibleIndexes.contains(selectedIndex) {
            selectedIndex = visibleIndexes[0]
        }
    }

    private static func clampedPaneWidthRatio(_ ratio: Double) -> Double {
        min(0.8, max(0.2, ratio))
    }

    private static func clampedMessageWindowHeightRatio(_ ratio: Double) -> Double {
        min(0.45, max(0.12, ratio))
    }

    private func sameNamedFile(
        _ item: FileItem,
        matches oppositeItem: FileItem,
        options: SameNamedFileMarkOptions
    ) -> Bool {
        if options.comparesByteSize, item.byteSize != oppositeItem.byteSize {
            return false
        }

        if options.comparesModificationDate, item.modificationDate != oppositeItem.modificationDate {
            return false
        }

        return true
    }
}

public struct SameNamedFileMarkOptions: Equatable {
    public var comparesByteSize: Bool
    public var comparesModificationDate: Bool

    public init(comparesByteSize: Bool = false, comparesModificationDate: Bool = false) {
        self.comparesByteSize = comparesByteSize
        self.comparesModificationDate = comparesModificationDate
    }
}

public enum IncrementalSearchMatchMode: String, Codable, Equatable, CaseIterable {
    case prefix
    case contains
    case exact
}

private enum FileNameMatchMode {
    case exactWildcard
    case incrementalSearch(IncrementalSearchMatchMode)
}

private enum FileNameWildcardMatcher {
    static func matches(_ name: String, pattern: String, mode: FileNameMatchMode) -> Bool {
        let nameCharacters = Array(name.lowercased())
        var normalizedPattern = normalizeWildcards(in: pattern)
        switch mode {
        case .exactWildcard:
            break
        case .incrementalSearch(.prefix):
            normalizedPattern += "*"
        case .incrementalSearch(.contains):
            normalizedPattern = "*" + normalizedPattern + "*"
        case .incrementalSearch(.exact):
            break
        }
        let patternCharacters = Array(normalizedPattern.lowercased())
        var memo: [SearchKey: Bool] = [:]

        func match(nameIndex: Int, patternIndex: Int) -> Bool {
            let key = SearchKey(nameIndex: nameIndex, patternIndex: patternIndex)
            if let cachedResult = memo[key] {
                return cachedResult
            }

            let result: Bool
            if patternIndex == patternCharacters.count {
                result = nameIndex == nameCharacters.count
            } else if patternCharacters[patternIndex] == "*" {
                result = match(nameIndex: nameIndex, patternIndex: patternIndex + 1)
                    || (nameIndex < nameCharacters.count && match(nameIndex: nameIndex + 1, patternIndex: patternIndex))
            } else if nameIndex < nameCharacters.count,
                      (patternCharacters[patternIndex] == "?"
                        || patternCharacters[patternIndex] == nameCharacters[nameIndex]) {
                result = match(nameIndex: nameIndex + 1, patternIndex: patternIndex + 1)
            } else {
                result = false
            }

            memo[key] = result
            return result
        }

        return match(nameIndex: 0, patternIndex: 0)
    }

    private static func normalizeWildcards(in pattern: String) -> String {
        pattern.map { character in
            switch character {
            case "＊":
                return "*"
            case "？":
                return "?"
            default:
                return String(character)
            }
        }.joined()
    }

    private struct SearchKey: Hashable {
        let nameIndex: Int
        let patternIndex: Int
    }
}

public enum FileSortCriterion: String, Codable, Equatable {
    case name
    case fileExtension
    case byteSize
    case modificationDate

    public var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .fileExtension:
            return "Extension"
        case .byteSize:
            return "Size"
        case .modificationDate:
            return "Modified"
        }
    }
}

public enum SortDirection: String, Codable, Equatable {
    case ascending
    case descending

    public var displaySymbol: String {
        switch self {
        case .ascending:
            return "Asc"
        case .descending:
            return "Desc"
        }
    }

    fileprivate var multiplier: Int {
        switch self {
        case .ascending:
            return 1
        case .descending:
            return -1
        }
    }

    fileprivate func toggled() -> SortDirection {
        self == .ascending ? .descending : .ascending
    }
}

public struct FileSortDescriptor: Codable, Equatable {
    public static let `default` = FileSortDescriptor(criterion: .name, direction: .ascending)

    public let criterion: FileSortCriterion
    public let direction: SortDirection

    public init(criterion: FileSortCriterion, direction: SortDirection) {
        self.criterion = criterion
        self.direction = direction
    }

    public var displayText: String {
        "\(criterion.displayName) \(direction.displaySymbol)"
    }

    fileprivate func toggled(ifSameAs criterion: FileSortCriterion) -> FileSortDescriptor {
        if self.criterion == criterion {
            return FileSortDescriptor(criterion: criterion, direction: direction.toggled())
        }

        return FileSortDescriptor(criterion: criterion, direction: .ascending)
    }
}

private extension Array where Element == FileItem {
    mutating func sort(using descriptor: FileSortDescriptor) {
        sort { lhs, rhs in
            FileItemComparator.compare(lhs, rhs, using: descriptor) == .orderedAscending
        }
    }
}

private enum FileItemComparator {
    static func compare(_ lhs: FileItem, _ rhs: FileItem, using descriptor: FileSortDescriptor) -> ComparisonResult {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory ? .orderedAscending : .orderedDescending
        }

        let primaryResult = comparePrimary(lhs, rhs, using: descriptor)
        if primaryResult != .orderedSame {
            return descriptor.direction.multiplier == 1 ? primaryResult : primaryResult.reversed
        }

        return lhs.name.localizedStandardCompare(rhs.name)
    }

    private static func comparePrimary(
        _ lhs: FileItem,
        _ rhs: FileItem,
        using descriptor: FileSortDescriptor
    ) -> ComparisonResult {
        switch descriptor.criterion {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .fileExtension:
            return lhs.fileExtension.localizedStandardCompare(rhs.fileExtension)
        case .byteSize:
            return compareOptional(lhs.byteSize, rhs.byteSize)
        case .modificationDate:
            return compareOptional(lhs.modificationDate, rhs.modificationDate)
        }
    }

    private static func compareOptional<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
        switch (lhs, rhs) {
        case let (lhs?, rhs?):
            if lhs < rhs {
                return .orderedAscending
            }
            if lhs > rhs {
                return .orderedDescending
            }
            return .orderedSame
        case (nil, nil):
            return .orderedSame
        case (nil, _?):
            return .orderedDescending
        case (_?, nil):
            return .orderedAscending
        }
    }
}

private extension ComparisonResult {
    var reversed: ComparisonResult {
        switch self {
        case .orderedAscending:
            return .orderedDescending
        case .orderedDescending:
            return .orderedAscending
        case .orderedSame:
            return .orderedSame
        }
    }
}
