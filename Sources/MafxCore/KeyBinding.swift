import Foundation

public struct KeyStroke: Codable, Equatable, Hashable {
    public var key: String
    public var modifiers: KeyModifiers

    public init(key: String, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }

    public var displayText: String {
        let modifierText = modifiers.displayText
        return modifierText.isEmpty ? key : "\(modifierText)+\(key)"
    }
}

public struct KeyModifiers: OptionSet, Codable, Equatable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let shift = KeyModifiers(rawValue: 1 << 0)
    public static let control = KeyModifiers(rawValue: 1 << 1)
    public static let option = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)

    public var displayText: String {
        var parts: [String] = []
        if contains(.control) {
            parts.append("Control")
        }
        if contains(.option) {
            parts.append("Option")
        }
        if contains(.shift) {
            parts.append("Shift")
        }
        if contains(.command) {
            parts.append("Cmd")
        }
        return parts.joined(separator: "+")
    }
}

public struct KeyBindingSequence: Codable, Equatable, Hashable {
    public var strokes: [KeyStroke]

    public init(_ strokes: [KeyStroke]) {
        self.strokes = strokes
    }

    public init(_ stroke: KeyStroke) {
        self.strokes = [stroke]
    }

    public var displayText: String {
        strokes.map(\.displayText).joined(separator: ", ")
    }

    public func hasPrefix(_ prefix: [KeyStroke]) -> Bool {
        guard prefix.count <= strokes.count else {
            return false
        }

        return Array(strokes.prefix(prefix.count)) == prefix
    }
}

/// 複数ストローク入力の途中で選択できる、残りのキー列とコマンドの組み合わせです。
public struct KeyBindingCandidate: Equatable, Hashable {
    public let commandID: CommandID
    public let remainingStrokes: [KeyStroke]

    public init(commandID: CommandID, remainingStrokes: [KeyStroke]) {
        self.commandID = commandID
        self.remainingStrokes = remainingStrokes
    }

    public var remainingDisplayText: String {
        remainingStrokes.map(\.displayText).joined(separator: ", ")
    }
}

public enum KeyBindingContext: String, Codable, Equatable, CaseIterable {
    case mainPane
}

/// コマンドが操作対象とする範囲。モード中のキー解決でも一貫して利用する。
public enum CommandExecutionScope: Equatable {
    case application
    case activePane
    case preview
}

public enum CommandID: String, Codable, Equatable, CaseIterable {
    case moveSelectionUp
    case moveSelectionDown
    case moveSelectionPageUp
    case moveSelectionPageDown
    case activateLeftPane
    case activateRightPane
    case widenLeftPane
    case narrowLeftPane
    case enlargeMessageWindow
    case shrinkMessageWindow
    case historyBack
    case historyForward
    case openSelectedDirectory
    case openSelectedItem
    case openWithConfiguredApplication
    case showOpenWithMenu
    case previewSelectedFile
    case togglePreviewPane
    case enterPreviewMode
    case moveToParentDirectory
    case toggleMark
    case toggleMarkReverse
    case markRangeFromPreviousMarkedItem
    case clearMarkedItems
    case switchActivePane
    case beginWildcardMark
    case beginFileMask
    case beginIncrementalSearch
    case beginDirectPathInput
    case showNavigationHistory
    case invertMarkedFiles
    case invertMarkedFilesIncludingDirectories
    case showSameNamedFileMarkOptions
    case showSelectedItemInfo
    case copyFileNamesToClipboard
    case copyDirectoryPathsToClipboard
    case copyFullPathsToClipboard
    case copyMarkedItems
    case moveMarkedItems
    case trashMarkedItems
    case copySelectedItem
    case moveSelectedItem
    case trashSelectedItem
    case renameSelectedItem
    case copySelectedItemWithNewName
    case browseSelectedArchive
    case extractSelectedArchive
    case createArchiveFromMarkedItems
    case showContextMenu
    case syncActivePaneToOpposite
    case syncOppositePaneToActive
    case showJumpPathList
    case openJumpPath1
    case openJumpPath2
    case openJumpPath3
    case openJumpPath4
    case openJumpPath5
    case openJumpPath6
    case openJumpPath7
    case openJumpPath8
    case openJumpPath9
    case openJumpPath0
    case createFolder
    case showDriveList
    case showTagFilterList
    case showTagEditList
    case toggleHiddenFiles
    case openSettings
    case quitApplication
    case sortBySize
    case sortByExtension
    case sortByName
    case sortByModificationDate
    case increaseFileListFontSize
    case decreaseFileListFontSize
    case resetFileListFontSize

    public var title: String {
        switch self {
        case .moveSelectionUp:
            return "カーソルを上へ移動"
        case .moveSelectionDown:
            return "カーソルを下へ移動"
        case .moveSelectionPageUp:
            return "カーソルを1ページ上へ移動"
        case .moveSelectionPageDown:
            return "カーソルを1ページ下へ移動"
        case .activateLeftPane:
            return "左ペインをアクティブにする"
        case .activateRightPane:
            return "右ペインをアクティブにする"
        case .widenLeftPane:
            return "左ペインを広くする"
        case .narrowLeftPane:
            return "左ペインを狭くする"
        case .enlargeMessageWindow:
            return "メッセージウィンドウを高くする"
        case .shrinkMessageWindow:
            return "メッセージウィンドウを低くする"
        case .historyBack:
            return "履歴を戻る"
        case .historyForward:
            return "履歴を進む"
        case .openSelectedDirectory:
            return "選択中ディレクトリへ移動"
        case .openSelectedItem:
            return "選択中項目を開く"
        case .openWithConfiguredApplication:
            return "指定アプリで開く"
        case .showOpenWithMenu:
            return "このアプリケーションで開く"
        case .previewSelectedFile:
            return "選択中ファイルをプレビュー"
        case .togglePreviewPane:
            return "プレビューペインを表示／非表示"
        case .enterPreviewMode:
            return "プレビューモードに入る"
        case .moveToParentDirectory:
            return "親ディレクトリへ移動"
        case .toggleMark:
            return "マークを切り替える"
        case .toggleMarkReverse:
            return "マークを切り替えて前へ移動"
        case .markRangeFromPreviousMarkedItem:
            return "直前のマークから現在位置までマーク"
        case .clearMarkedItems:
            return "マークを全て解除"
        case .switchActivePane:
            return "アクティブペインを切り替える"
        case .beginWildcardMark:
            return "ワイルドカードマークを開始"
        case .beginFileMask:
            return "ファイルマスク入力を開始"
        case .beginIncrementalSearch:
            return "インクリメンタルサーチを開始"
        case .beginDirectPathInput:
            return "パス入力を開始"
        case .showNavigationHistory:
            return "履歴一覧を表示"
        case .invertMarkedFiles:
            return "ファイルのマーク状態を反転"
        case .invertMarkedFilesIncludingDirectories:
            return "ファイルとディレクトリのマーク状態を反転"
        case .showSameNamedFileMarkOptions:
            return "同名ファイル選択画面を表示"
        case .showSelectedItemInfo:
            return "選択中項目の情報を表示"
        case .copyFileNamesToClipboard:
            return "ファイル名をクリップボードへコピー"
        case .copyDirectoryPathsToClipboard:
            return "パスをクリップボードへコピー"
        case .copyFullPathsToClipboard:
            return "フルパスをクリップボードへコピー"
        case .copyMarkedItems:
            return "マーク済み項目をコピー"
        case .moveMarkedItems:
            return "マーク済み項目を移動"
        case .trashMarkedItems:
            return "マーク済み項目をゴミ箱へ移動"
        case .copySelectedItem:
            return "選択中項目をコピー"
        case .moveSelectedItem:
            return "選択中項目を移動"
        case .trashSelectedItem:
            return "選択中項目をゴミ箱へ移動"
        case .renameSelectedItem:
            return "選択中項目の名前を変更"
        case .copySelectedItemWithNewName:
            return "選択中項目を別名でコピー"
        case .browseSelectedArchive:
            return "選択中 ZIP の内容を確認"
        case .extractSelectedArchive:
            return "選択中 ZIP を展開"
        case .createArchiveFromMarkedItems:
            return "マーク済み項目を ZIP に圧縮"
        case .showContextMenu:
            return "コンテキストメニューを表示"
        case .syncActivePaneToOpposite:
            return "アクティブペインを逆窓のパスに同期"
        case .syncOppositePaneToActive:
            return "逆窓をアクティブペインのパスに同期"
        case .showJumpPathList:
            return "登録パス一覧を表示"
        case .openJumpPath1:
            return "登録パス1へ移動"
        case .openJumpPath2:
            return "登録パス2へ移動"
        case .openJumpPath3:
            return "登録パス3へ移動"
        case .openJumpPath4:
            return "登録パス4へ移動"
        case .openJumpPath5:
            return "登録パス5へ移動"
        case .openJumpPath6:
            return "登録パス6へ移動"
        case .openJumpPath7:
            return "登録パス7へ移動"
        case .openJumpPath8:
            return "登録パス8へ移動"
        case .openJumpPath9:
            return "登録パス9へ移動"
        case .openJumpPath0:
            return "登録パス10へ移動"
        case .createFolder:
            return "フォルダを作成"
        case .showDriveList:
            return "場所一覧を表示"
        case .showTagFilterList:
            return "タグ一覧を表示"
        case .showTagEditList:
            return "タグを設定・解除"
        case .toggleHiddenFiles:
            return "隠しファイル表示を切り替える"
        case .openSettings:
            return "設定ウィンドウを開く"
        case .quitApplication:
            return "アプリケーションを終了"
        case .sortBySize:
            return "ファイルサイズでソート"
        case .sortByExtension:
            return "拡張子でソート"
        case .sortByName:
            return "ファイル名でソート"
        case .sortByModificationDate:
            return "更新日時でソート"
        case .increaseFileListFontSize:
            return "ファイル一覧のフォントサイズを拡大"
        case .decreaseFileListFontSize:
            return "ファイル一覧のフォントサイズを縮小"
        case .resetFileListFontSize:
            return "ファイル一覧のフォントサイズを標準に戻す"
        }
    }

    public var localizationKey: String {
        "command.\(rawValue)"
    }

    public var executionScope: CommandExecutionScope {
        switch self {
        case .togglePreviewPane, .openSettings, .quitApplication,
             .toggleHiddenFiles, .increaseFileListFontSize,
             .decreaseFileListFontSize, .resetFileListFontSize:
            return .application
        case .enterPreviewMode:
            return .preview
        default:
            return .activePane
        }
    }

    public var category: KeyBindingCategory {
        switch self {
        case .moveSelectionUp, .moveSelectionDown, .moveSelectionPageUp, .moveSelectionPageDown,
             .activateLeftPane, .activateRightPane, .switchActivePane, .openSelectedDirectory,
             .openSelectedItem, .openWithConfiguredApplication, .showOpenWithMenu, .previewSelectedFile, .togglePreviewPane, .enterPreviewMode, .moveToParentDirectory, .historyBack, .historyForward, .showNavigationHistory,
             .syncActivePaneToOpposite, .syncOppositePaneToActive, .showJumpPathList, .beginDirectPathInput,
             .openJumpPath1, .openJumpPath2, .openJumpPath3, .openJumpPath4, .openJumpPath5,
             .openJumpPath6, .openJumpPath7, .openJumpPath8, .openJumpPath9, .openJumpPath0,
             .showDriveList,
             .showTagFilterList,
             .showSelectedItemInfo:
            return .navigation
        case .widenLeftPane, .narrowLeftPane, .enlargeMessageWindow, .shrinkMessageWindow:
            return .pane
        case .toggleMark, .toggleMarkReverse, .markRangeFromPreviousMarkedItem,
             .clearMarkedItems, .invertMarkedFiles,
             .invertMarkedFilesIncludingDirectories, .beginWildcardMark, .showSameNamedFileMarkOptions,
             .showTagEditList, .copyFileNamesToClipboard, .copyDirectoryPathsToClipboard,
             .copyFullPathsToClipboard:
            return .selection
        case .copyMarkedItems, .moveMarkedItems, .trashMarkedItems,
             .copySelectedItem, .moveSelectedItem, .trashSelectedItem,
             .renameSelectedItem, .copySelectedItemWithNewName, .browseSelectedArchive,
             .extractSelectedArchive, .createArchiveFromMarkedItems, .createFolder:
            return .fileOperation
        case .showContextMenu:
            return .application
        case .beginFileMask, .beginIncrementalSearch:
            return .search
        case .sortBySize, .sortByExtension, .sortByName, .sortByModificationDate:
            return .sort
        case .increaseFileListFontSize, .decreaseFileListFontSize, .resetFileListFontSize:
            return .pane
        case .toggleHiddenFiles, .openSettings, .quitApplication:
            return .application
        }
    }
}

public enum KeyBindingCategory: String, Codable, Equatable, CaseIterable {
    case navigation = "Navigation"
    case pane = "Pane"
    case selection = "Selection"
    case fileOperation = "File Operation"
    case search = "Search"
    case sort = "Sort"
    case application = "Application"

    public var localizationKey: String {
        "keyBindingCategory.\(rawValue)"
    }
}

public struct KeyBindingEntry: Codable, Equatable {
    public var commandID: CommandID
    public var context: KeyBindingContext
    public var sequences: [KeyBindingSequence]

    public init(
        commandID: CommandID,
        context: KeyBindingContext = .mainPane,
        sequences: [KeyBindingSequence]
    ) {
        self.commandID = commandID
        self.context = context
        self.sequences = sequences
    }
}

public enum KeymapResolution: Equatable {
    case matched(CommandID)
    case awaitingNextStroke(PendingKeySequence)
    case unmatched
}

public struct PendingKeySequence: Equatable {
    public let strokes: [KeyStroke]

    public init(strokes: [KeyStroke]) {
        self.strokes = strokes
    }

    public var displayText: String {
        KeyBindingSequence(strokes).displayText
    }

}

public enum KeyBindingConflictKind: Equatable {
    case duplicate
    case prefix
}

public struct KeyBindingConflict: Equatable {
    public var kind: KeyBindingConflictKind
    public var firstCommandID: CommandID
    public var secondCommandID: CommandID
    public var sequence: KeyBindingSequence
}

public struct KeyBindingSet: Codable, Equatable {
    public var entries: [KeyBindingEntry]

    public init(entries: [KeyBindingEntry] = KeyBindingSet.default.entries) {
        self.entries = entries
    }

    public static let `default` = KeyBindingSet(entries: [
        KeyBindingEntry(commandID: .moveSelectionUp, sequences: [.init(.init(key: "Up"))]),
        KeyBindingEntry(commandID: .moveSelectionDown, sequences: [.init(.init(key: "Down"))]),
        KeyBindingEntry(commandID: .moveSelectionPageUp, sequences: [.init(.init(key: "PageUp"))]),
        KeyBindingEntry(commandID: .moveSelectionPageDown, sequences: [.init(.init(key: "PageDown"))]),
        KeyBindingEntry(commandID: .activateLeftPane, sequences: [.init(.init(key: "Left"))]),
        KeyBindingEntry(commandID: .activateRightPane, sequences: [.init(.init(key: "Right"))]),
        KeyBindingEntry(commandID: .narrowLeftPane, sequences: [.init(.init(key: "Left", modifiers: .option))]),
        KeyBindingEntry(commandID: .widenLeftPane, sequences: [.init(.init(key: "Right", modifiers: .option))]),
        KeyBindingEntry(commandID: .enlargeMessageWindow, sequences: [.init(.init(key: "Up", modifiers: .option))]),
        KeyBindingEntry(commandID: .shrinkMessageWindow, sequences: [.init(.init(key: "Down", modifiers: .option))]),
        KeyBindingEntry(commandID: .historyBack, sequences: [.init(.init(key: "Left", modifiers: .command))]),
        KeyBindingEntry(commandID: .historyForward, sequences: [.init(.init(key: "Right", modifiers: .command))]),
        KeyBindingEntry(commandID: .openSelectedDirectory, sequences: []),
        KeyBindingEntry(commandID: .openSelectedItem, sequences: [.init(.init(key: "Return", modifiers: .command))]),
        KeyBindingEntry(commandID: .openWithConfiguredApplication, sequences: [.init(.init(key: "Return", modifiers: .control))]),
        KeyBindingEntry(commandID: .showOpenWithMenu, sequences: []),
        KeyBindingEntry(commandID: .previewSelectedFile, sequences: [.init(.init(key: "V"))]),
        KeyBindingEntry(commandID: .togglePreviewPane, sequences: [.init(.init(key: "V", modifiers: .shift))]),
        KeyBindingEntry(commandID: .enterPreviewMode, sequences: [.init(.init(key: "V", modifiers: .option))]),
        KeyBindingEntry(commandID: .moveToParentDirectory, sequences: [.init(.init(key: "Backspace"))]),
        KeyBindingEntry(commandID: .toggleMark, sequences: [.init(.init(key: "Space"))]),
        KeyBindingEntry(commandID: .toggleMarkReverse, sequences: [.init(.init(key: "Space", modifiers: .shift))]),
        KeyBindingEntry(commandID: .markRangeFromPreviousMarkedItem, sequences: [
            .init(.init(key: "Space", modifiers: [.control, .shift]))
        ]),
        KeyBindingEntry(commandID: .clearMarkedItems, sequences: [.init(.init(key: "End"))]),
        KeyBindingEntry(commandID: .switchActivePane, sequences: [.init(.init(key: "Tab"))]),
        KeyBindingEntry(commandID: .beginWildcardMark, sequences: [.init(.init(key: "@", modifiers: .shift))]),
        KeyBindingEntry(commandID: .beginFileMask, sequences: [.init(.init(key: ":", modifiers: .shift))]),
        KeyBindingEntry(commandID: .beginIncrementalSearch, sequences: [.init(.init(key: "F"))]),
        KeyBindingEntry(commandID: .showNavigationHistory, sequences: [.init(.init(key: "H"))]),
        KeyBindingEntry(commandID: .invertMarkedFiles, sequences: [.init(.init(key: "A"))]),
        KeyBindingEntry(commandID: .invertMarkedFilesIncludingDirectories, sequences: [.init(.init(key: "A", modifiers: .shift))]),
        KeyBindingEntry(commandID: .showSameNamedFileMarkOptions, sequences: [.init(.init(key: "W"))]),
        KeyBindingEntry(commandID: .showSelectedItemInfo, sequences: [.init(.init(key: "I"))]),
        KeyBindingEntry(commandID: .copyFileNamesToClipboard, sequences: [.init([.init(key: "P"), .init(key: "1")])]),
        KeyBindingEntry(commandID: .copyDirectoryPathsToClipboard, sequences: [.init([.init(key: "P"), .init(key: "2")])]),
        KeyBindingEntry(commandID: .copyFullPathsToClipboard, sequences: [.init([.init(key: "P"), .init(key: "3")])]),
        KeyBindingEntry(commandID: .copyMarkedItems, sequences: [.init(.init(key: "C"))]),
        KeyBindingEntry(commandID: .moveMarkedItems, sequences: [.init(.init(key: "M"))]),
        KeyBindingEntry(commandID: .trashMarkedItems, sequences: [.init(.init(key: "D"))]),
        KeyBindingEntry(commandID: .copySelectedItem, sequences: []),
        KeyBindingEntry(commandID: .moveSelectedItem, sequences: []),
        KeyBindingEntry(commandID: .trashSelectedItem, sequences: []),
        KeyBindingEntry(commandID: .renameSelectedItem, sequences: [.init(.init(key: "R"))]),
        KeyBindingEntry(commandID: .copySelectedItemWithNewName, sequences: [.init(.init(key: "R", modifiers: .shift))]),
        KeyBindingEntry(commandID: .browseSelectedArchive, sequences: [.init([.init(key: "X"), .init(key: "O")])]),
        KeyBindingEntry(commandID: .extractSelectedArchive, sequences: [.init([.init(key: "X"), .init(key: "E")])]),
        KeyBindingEntry(commandID: .createArchiveFromMarkedItems, sequences: [.init([.init(key: "X"), .init(key: "C")])]),
        KeyBindingEntry(commandID: .showContextMenu, sequences: [
            .init(.init(key: "/"))
        ]),
        KeyBindingEntry(commandID: .syncActivePaneToOpposite, sequences: [.init(.init(key: "O"))]),
        KeyBindingEntry(commandID: .syncOppositePaneToActive, sequences: [.init(.init(key: "O", modifiers: .shift))]),
        KeyBindingEntry(commandID: .showJumpPathList, sequences: [.init(.init(key: "J"))]),
        KeyBindingEntry(commandID: .openJumpPath1, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath2, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath3, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath4, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath5, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath6, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath7, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath8, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath9, sequences: []),
        KeyBindingEntry(commandID: .openJumpPath0, sequences: []),
        KeyBindingEntry(commandID: .beginDirectPathInput, sequences: [.init(.init(key: "J", modifiers: .shift))]),
        KeyBindingEntry(commandID: .createFolder, sequences: [.init(.init(key: "K"))]),
        KeyBindingEntry(commandID: .showDriveList, sequences: [.init(.init(key: "L"))]),
        KeyBindingEntry(commandID: .showTagFilterList, sequences: [.init(.init(key: "T"))]),
        KeyBindingEntry(commandID: .showTagEditList, sequences: [.init(.init(key: "T", modifiers: .shift))]),
        KeyBindingEntry(commandID: .toggleHiddenFiles, sequences: []),
        KeyBindingEntry(commandID: .openSettings, sequences: [
            .init(.init(key: "Z")),
            .init(.init(key: ",", modifiers: .command))
        ]),
        KeyBindingEntry(commandID: .quitApplication, sequences: [.init(.init(key: "Q"))]),
        KeyBindingEntry(commandID: .sortBySize, sequences: [.init([.init(key: "S"), .init(key: "S")])]),
        KeyBindingEntry(commandID: .sortByExtension, sequences: [.init([.init(key: "S"), .init(key: "E")])]),
        KeyBindingEntry(commandID: .sortByName, sequences: [.init([.init(key: "S"), .init(key: "F")])]),
        KeyBindingEntry(commandID: .sortByModificationDate, sequences: [.init([.init(key: "S"), .init(key: "T")])]),
        KeyBindingEntry(commandID: .increaseFileListFontSize, sequences: [.init(.init(key: "+", modifiers: [.shift, .command]))]),
        KeyBindingEntry(commandID: .decreaseFileListFontSize, sequences: [.init(.init(key: "-", modifiers: .command))]),
        KeyBindingEntry(commandID: .resetFileListFontSize, sequences: [.init(.init(key: "0", modifiers: .command))])
    ])

    public func sequences(for commandID: CommandID, context: KeyBindingContext = .mainPane) -> [KeyBindingSequence] {
        entries.first { $0.commandID == commandID && $0.context == context }?.sequences ?? []
    }

    public mutating func setSequences(
        _ sequences: [KeyBindingSequence],
        for commandID: CommandID,
        context: KeyBindingContext = .mainPane
    ) {
        if let index = entries.firstIndex(where: { $0.commandID == commandID && $0.context == context }) {
            entries[index].sequences = sequences
        } else {
            entries.append(KeyBindingEntry(commandID: commandID, context: context, sequences: sequences))
        }
    }

    public mutating func addSequence(
        _ sequence: KeyBindingSequence,
        to commandID: CommandID,
        context: KeyBindingContext = .mainPane
    ) {
        var current = sequences(for: commandID, context: context)
        guard !current.contains(sequence) else {
            return
        }
        current.append(sequence)
        setSequences(current, for: commandID, context: context)
    }

    public mutating func removeSequence(
        at index: Int,
        from commandID: CommandID,
        context: KeyBindingContext = .mainPane
    ) {
        var current = sequences(for: commandID, context: context)
        guard current.indices.contains(index) else {
            return
        }
        current.remove(at: index)
        setSequences(current, for: commandID, context: context)
    }

    public mutating func resetCommandToDefault(_ commandID: CommandID, context: KeyBindingContext = .mainPane) {
        setSequences(KeyBindingSet.default.sequences(for: commandID, context: context), for: commandID, context: context)
    }

    public mutating func resetToDefault() {
        entries = KeyBindingSet.default.entries
    }

    public func fillingMissingDefaultEntries() -> KeyBindingSet {
        var merged = self
        for defaultEntry in KeyBindingSet.default.entries {
            let hasEntry = merged.entries.contains {
                $0.commandID == defaultEntry.commandID && $0.context == defaultEntry.context
            }
            if !hasEntry {
                merged.entries.append(defaultEntry)
            }
        }
        return merged
    }

    /// メインペインの修飾キーなし Return は `ReturnKeyBehavior` 専用とする。
    /// 既存設定を読み込む際にも、この予約キーが通常コマンドへ渡らないようにする。
    public func reservingUnmodifiedReturn() -> KeyBindingSet {
        var updated = self
        let reservedSequence = KeyBindingSequence(KeyStroke(key: "Return"))
        for index in updated.entries.indices where updated.entries[index].context == .mainPane {
            updated.entries[index].sequences.removeAll { $0 == reservedSequence }
        }
        return updated
    }

    public func conflicts(context: KeyBindingContext = .mainPane) -> [KeyBindingConflict] {
        let contextEntries = entries.filter { $0.context == context }
        var conflicts: [KeyBindingConflict] = []

        for firstEntryIndex in contextEntries.indices {
            for secondEntryIndex in contextEntries.indices where secondEntryIndex > firstEntryIndex {
                let firstEntry = contextEntries[firstEntryIndex]
                let secondEntry = contextEntries[secondEntryIndex]

                for firstSequence in firstEntry.sequences {
                    for secondSequence in secondEntry.sequences {
                        if firstSequence == secondSequence {
                            conflicts.append(KeyBindingConflict(
                                kind: .duplicate,
                                firstCommandID: firstEntry.commandID,
                                secondCommandID: secondEntry.commandID,
                                sequence: firstSequence
                            ))
                        } else if firstSequence.hasPrefix(secondSequence.strokes) {
                            conflicts.append(KeyBindingConflict(
                                kind: .prefix,
                                firstCommandID: secondEntry.commandID,
                                secondCommandID: firstEntry.commandID,
                                sequence: secondSequence
                            ))
                        } else if secondSequence.hasPrefix(firstSequence.strokes) {
                            conflicts.append(KeyBindingConflict(
                                kind: .prefix,
                                firstCommandID: firstEntry.commandID,
                                secondCommandID: secondEntry.commandID,
                                sequence: firstSequence
                            ))
                        }
                    }
                }
            }
        }

        return conflicts
    }
}

public final class KeymapResolver {
    private let keyBindingSet: KeyBindingSet
    private let context: KeyBindingContext
    private var pendingStrokes: [KeyStroke] = []

    public init(keyBindingSet: KeyBindingSet = .default, context: KeyBindingContext = .mainPane) {
        self.keyBindingSet = keyBindingSet
        self.context = context
    }

    public func resetPendingStrokes() {
        pendingStrokes.removeAll()
    }

    /// 指定した入力済みキー列に続く、実行可能なコマンド候補を返します。
    ///
    /// UI はこの結果だけを表示し、キーバインド定義を直接探索しません。
    public func candidates(
        for pendingSequence: PendingKeySequence,
        allowedCommandIDs: Set<CommandID>? = nil
    ) -> [KeyBindingCandidate] {
        let prefix = pendingSequence.strokes
        var candidates: [KeyBindingCandidate] = []
        var seen = Set<KeyBindingCandidate>()

        for entry in keyBindingSet.entries where entry.context == context
            && (allowedCommandIDs?.contains(entry.commandID) ?? true) {
            for sequence in entry.sequences where sequence.hasPrefix(prefix) && sequence.strokes.count > prefix.count {
                let candidate = KeyBindingCandidate(
                    commandID: entry.commandID,
                    remainingStrokes: Array(sequence.strokes.dropFirst(prefix.count))
                )
                if seen.insert(candidate).inserted {
                    candidates.append(candidate)
                }
            }
        }

        return candidates
    }

    public func resolve(
        _ stroke: KeyStroke,
        allowedCommandIDs: Set<CommandID>? = nil
    ) -> KeymapResolution {
        pendingStrokes.append(stroke)

        let matchingEntries = keyBindingSet.entries.filter { entry in
            entry.context == context
                && (allowedCommandIDs?.contains(entry.commandID) ?? true)
                && entry.sequences.contains { $0.hasPrefix(pendingStrokes) }
        }
        let exactMatches = matchingEntries.compactMap { entry -> CommandID? in
            entry.sequences.contains { $0.strokes == pendingStrokes } ? entry.commandID : nil
        }
        let hasLongerMatch = matchingEntries.contains { entry in
            entry.sequences.contains { $0.hasPrefix(pendingStrokes) && $0.strokes.count > pendingStrokes.count }
        }

        if exactMatches.count == 1, !hasLongerMatch {
            pendingStrokes.removeAll()
            return .matched(exactMatches[0])
        }

        if hasLongerMatch {
            return .awaitingNextStroke(PendingKeySequence(strokes: pendingStrokes))
        }

        pendingStrokes.removeAll()
        return .unmatched
    }
}
