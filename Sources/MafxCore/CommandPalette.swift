import Foundation

public struct CommandPaletteItem: Equatable {
    public let commandID: CommandID
    public let title: String
    public let category: String
    public let keywords: [String]
    public let bindings: [String]

    public let englishTitle: String?
    public let englishCategory: String?
    public let englishKeywords: [String]

    public init(commandID: CommandID, title: String, category: String, keywords: [String], bindings: [String],
                englishTitle: String? = nil, englishCategory: String? = nil, englishKeywords: [String] = []) {
        self.commandID = commandID
        self.title = title
        self.category = category
        self.keywords = keywords
        self.bindings = bindings
        self.englishTitle = englishTitle
        self.englishCategory = englishCategory
        self.englishKeywords = englishKeywords
    }
}

public enum CommandPaletteSearch {
    public static func results(for query: String, in items: [CommandPaletteItem]) -> [CommandPaletteItem] {
        let terms = query.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }
        guard !terms.isEmpty else { return items }

        return items.enumerated().compactMap { index, item -> (Int, Int, CommandPaletteItem)? in
            let title = normalize(item.title)
            let category = normalize(item.category)
            let englishTitle = item.englishTitle.map(normalize)
            let englishCategory = item.englishCategory.map(normalize)
            let keywords = (item.keywords + item.englishKeywords).map(normalize)
            let bindings = item.bindings.map(normalize)
            guard terms.allSatisfy({ term in
                title.contains(term) || category.contains(term)
                    || englishTitle?.contains(term) == true || englishCategory?.contains(term) == true
                    || keywords.contains(where: { $0.contains(term) })
                    || bindings.contains(where: { $0.contains(term) })
            }) else { return nil }
            let rank: Int
            if terms.count == 1 && (title == terms[0] || englishTitle == terms[0]) { rank = 0 }
            else if terms.allSatisfy({ title.hasPrefix($0) || englishTitle?.hasPrefix($0) == true }) { rank = 1 }
            else if terms.allSatisfy({ title.contains($0) || englishTitle?.contains($0) == true }) { rank = 2 }
            else if terms.allSatisfy({ term in keywords.contains(where: { $0.contains(term) }) }) { rank = 3 }
            else { rank = 4 }
            return (rank, index, item)
        }.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.map { $0.2 }
    }

    /// 表示中の項目では説明できない検索語を、英語の名称・カテゴリ・関連語で説明する。
    public static func englishMatchExplanation(for query: String, in item: CommandPaletteItem) -> [String] {
        let localFields = [item.title, item.category] + item.keywords + item.bindings
        let terms = query.split(whereSeparator: \.isWhitespace).map { normalize(String($0)) }
        let englishTerms = terms.filter { term in
            !localFields.contains { normalize($0).contains(term) }
        }
        guard !englishTerms.isEmpty else { return [] }
        var explanation: [String] = []
        if let title = item.englishTitle { explanation.append(title) }
        let remaining = englishTerms.filter { term in
            !(item.englishTitle.map { normalize($0).contains(term) } ?? false)
        }
        for field in [item.englishCategory].compactMap({ $0 }) + item.englishKeywords {
            if remaining.contains(where: { normalize(field).contains($0) }), !explanation.contains(field) {
                explanation.append(field)
            }
        }
        return explanation
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: .current)
    }
}

public struct CommandPaletteUsageHistory: Codable, Equatable {
    public static let maximumEntryCount = 10
    public private(set) var entries: [CommandID]

    public init(entries: [CommandID] = []) {
        self.entries = []
        for entry in entries.reversed() { record(entry) }
    }

    public mutating func record(_ commandID: CommandID) {
        entries.removeAll { $0 == commandID }
        entries.insert(commandID, at: 0)
        entries = Array(entries.prefix(Self.maximumEntryCount))
    }
}

public enum CommandPaletteSection: Equatable {
    case recent, all
}

public enum CommandPaletteRow: Equatable {
    case heading(CommandPaletteSection)
    case command(CommandPaletteItem)

    public var item: CommandPaletteItem? {
        if case .command(let item) = self { return item }
        return nil
    }
}

public enum CommandPaletteList {
    public static func rows(for query: String, in items: [CommandPaletteItem],
                            history: CommandPaletteUsageHistory) -> [CommandPaletteRow] {
        guard query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return CommandPaletteSearch.results(for: query, in: items).map { .command($0) }
        }
        let recent = history.entries.compactMap { commandID in
            items.first { $0.commandID == commandID }
        }
        guard !recent.isEmpty else { return items.map { .command($0) } }
        return [.heading(.recent)] + recent.map { .command($0) }
            + [.heading(.all)] + items.map { .command($0) }
    }

    public static func selection(in rows: [CommandPaletteRow], from current: Int, moving delta: Int) -> Int? {
        let selectable = rows.indices.filter { rows[$0].item != nil }
        guard let first = selectable.first, let last = selectable.last else { return nil }
        if delta > 0 { return selectable.first { $0 > current } ?? last }
        return selectable.last { $0 < current } ?? first
    }
}

/// 使用履歴は portable settings に含めず、この端末だけに保存する。
public final class CommandPaletteHistoryRepository {
    private static let key = "commandPalette.usageHistory"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> CommandPaletteUsageHistory {
        guard let data = defaults.data(forKey: Self.key),
              let entries = try? JSONDecoder().decode([String].self, from: data) else {
            return CommandPaletteUsageHistory()
        }
        return CommandPaletteUsageHistory(entries: entries.compactMap(CommandID.init(rawValue:)))
    }

    public func save(_ history: CommandPaletteUsageHistory) {
        guard let data = try? JSONEncoder().encode(history.entries.map(\.rawValue)) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
